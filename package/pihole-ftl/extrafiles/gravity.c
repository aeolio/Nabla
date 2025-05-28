/* Pi-hole: A black hole for Internet advertisements
 *  (c) 2017 Pi-hole, LLC (https://pi-hole.net)
 *  Network-wide ad blocking via your own hardware.
 *
 *  FTL Engine
 *	Gravity database handling
 *
 *  This file is copyright under the latest version of the EUPL.
 *  Please see LICENSE file for your rights under this license.
 */

#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <errno.h>
#include <libgen.h>	// dirname
#include <pwd.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <time.h>
#include <utime.h>
#include <unistd.h>

// libraries
#include <curl/curl.h>
#include <sqlite3.h>
#include <openssl/sha.h>

//#include "args.h"
#include "config/config.h"	// readFTLconf()
#include "tools/gravity-parseList.h"	// gravity_parseList()
#include "log.h"
#include "gravity.h"

// database/shell.c does not have a header
extern int sqlite3_shell_main(int argc, char **argv);

static bool force_recover = false;
static bool force_deletion = false;
static bool display_timing = false;

/*
 * command verbs
 */
enum command_verb {
	REPAIR = 1,
	RECOVER,
	UPGRADE,
} __attribute__ ((packed));
static int command = 0;

/*
 * change status
 */
enum change_status {
	CHANGED_UPSTREAM = 1,
	UNCHANGED,
	FAILED_CACHED,
	FAILED_MISSING,
} __attribute__ ((packed));

/*
 * ip adress parse options
 */
enum ip_address_parse {
	loose = 1,
	strict,
} __attribute__ ((packed));

/*
 * database vw_adlist structure 
 */
#define FN_LIST 386
#define LIST_PREFIX "list"
#define LIST_POSTFIX "domains"
#define LIST_ETAG "etag"
#define LIST_CHKSUM "sha1"
struct blocklist {
	int id;
	char *address;
	int type;	// 0 == gravity, 1 == antigravity
	int count;
	int file_status;
	// below values are bot contained in database
	char *domain;
	char *filename;
	bool db_entry_exists;
	struct blocklist *next;
};

/*
 * configuration data 
 */
#define FN_SIZE 256
#define DN_SIZE (FN_SIZE-32)
struct config_data {
	// read from configuration
	char gravity_db_file[FN_SIZE];
	char gravity_tempdir[FN_SIZE];
	// filled from db_file
	char gravity_directory[FN_SIZE];
	char gravity_db_tmpfile[FN_SIZE];
	// filled from gravity_directory
	char gravity_db_oldfile[FN_SIZE];
	char gravity_db_backup_dir[FN_SIZE];
	// filled from gravity_db_backup_dir
	char gravity_db_backup_file[FN_SIZE];
	// filled from gravity_directory
	char list_cache_directory[FN_SIZE];
	struct blocklist *vw_adlist;
};
struct config_data configuration;

/*
 * Default blocklist for an empty database
 */
#define DEFAULT_LIST_PROVIDER "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

/*
 * system fixed data
 */
#define PIHOLE_SCRIPTDIR "/var/lib/pihole"
#define GRAVITY_DBSCHEMA_SCRIPT "advanced/Templates/gravity.db.sql"
#define GRAVITY_DBCOPY_SCRIPT "advanced/Templates/gravity_copy.sql"

#define	_PRINT_DEBUG_OUTPUT 1
#define	_DEBUG_IP_PARSER	0
#define	_FAKE_CHANGED_UPSTREAM	0

// forward declaration necessary because of function grouping
static void _add_listentry(struct config_data *, const struct blocklist *);


// === string manipulation functions ==========================================

// copy string between two pointer locations
static void _strpcpy(char *buffer, char *first, char *last) {
	int i;
	for ( i = 0 ; first+i < last ; i++ )
		buffer[i] = first[i];
	buffer[i] = 0;
	}

// convert integer to string
static char *i2str( char *buffer, int value ) {
	sprintf(buffer, "%d", value);
	return buffer;
	}

// convert long long integer to string
static char *lli2str( char *buffer, long long int value ) {
	sprintf(buffer, "%lld", value);
	return buffer;
	}

#define PIHOLE_USER "pihole"
#define DIR_ACCESS 00744
#define FILE_ACCESS 00644
#define PWD_TEXT_SIZE 1024
static int _set_file_permissions( const char *filename ) {
	int result;
	struct passwd pw, *ppw;
	if (char *pwd_text = calloc(PWD_TEXT_SIZE, 1)) {
		if ((result = getpwnam_r(PIHOLE_USER, &pw, 
			pwd_text, PWD_TEXT_SIZE, &ppw)) != EXIT_SUCCESS)
			goto _set_file_permissions_failure;
		if (ppw != NULL) {
			if ((result = chown(filename, ppw->pw_uid, ppw->pw_gid)) != EXIT_SUCCESS)
				goto _set_file_permissions_failure;
			if ((result = chmod(filename, FILE_ACCESS)) != EXIT_SUCCESS)
				goto _set_file_permissions_failure;
			}
		else
			result = EXIT_FAILURE;
_set_file_permissions_failure:
		free(pwd_text);
		}
	return result;
	}


// === o/s related functions ==================================================

/*
 * check if file exists, similar to [ -f ]
 */
static bool os_is_file(const char *filename) {

	if (access(filename, F_OK) == EXIT_SUCCESS)
		return true;
	return false;
	}

/*
 * check if path is a directory, similar to [ -d ]
 */
static bool os_is_directory(const char *pathname) {

	struct stat st;
	if (stat(pathname, &st) == EXIT_SUCCESS)
		return (st.st_mode & S_IFDIR);
	return false;
	}

/*
 * remove file, corresponds to rm -f
 */
static bool os_remove(const char *filename)
{
	if( access(filename, F_OK) == 0 ) {
		if( remove(filename) != 0 ) {
			printf("Could not remove %s: %s\n", filename, strerror(errno));
			return false;
		}
	}
	return true;
}

/*
 * file copy, similar to cp
 */
static int os_copy( const char *source_file, const char *target_file ) {

	struct stat st[2];
	// first file has to exist
	if (stat(source_file, &st[0]) != EXIT_SUCCESS)
		return EXIT_FAILURE;

	errno = 0;

	size_t block_size = st[0].st_blksize;
	if (char *buffer = calloc(1, block_size)) {
		if (FILE *s = fopen(source_file, "rb")) {
			if (FILE *t = fopen(target_file, "wb")) {
				size_t sz;
				while ((sz = fread(buffer, 1, block_size, s)) > 0) {
					if (fwrite(buffer, 1, sz, t) != sz)
						break;
					}
				fclose(t);
				}
			fclose(s);
			}
		free (buffer);
		}

	if (errno)
		return EXIT_FAILURE;

	if (stat(target_file, &st[1]) == EXIT_FAILURE)
		return EXIT_FAILURE;
	if (st[1].st_size != st[0].st_size)
		goto os_copy_fail;

	if (chown(target_file, st[0].st_uid, st[0].st_gid) != EXIT_SUCCESS)
		goto os_copy_fail;
	if (chmod(target_file, st[0].st_mode) != EXIT_SUCCESS)
		goto os_copy_fail;

	struct utimbuf ut;
	ut.actime = st[0].st_atime;
	ut.modtime = st[0].st_mtime;
	utime(target_file, &ut);

	return EXIT_SUCCESS;

os_copy_fail:
	if (os_is_file(target_file))
		remove(target_file);
	return EXIT_FAILURE;
	}

/*
 * get remaining space on file system
 */
#define STD_BLK_SIZE	512
static unsigned long long os_vfs_avail( const char *directory ) {

	struct statvfs vfs_status;
	unsigned long long available = 0;

	if( (statvfs(directory, &vfs_status)) == EXIT_SUCCESS ) {
		/* if block size is missing, use standard block size */
		if(vfs_status.f_bsize == 0)
			vfs_status.f_bsize = STD_BLK_SIZE;
		available = (unsigned long long) vfs_status.f_bavail *
			(unsigned long long) vfs_status.f_bsize;
		}
	return available;
	}

/*
 * returns file size
 */
static unsigned long long os_fsize( const char *filename ) {

	struct stat f_status;
	if (stat(filename, &f_status) == EXIT_SUCCESS)
		return f_status.st_size;
	return 0;
	}

/*
 * rename a file; if necessary, move it between mount points, similar to mv
 */
static int os_rename( const char *source_file, const char *target_file ) {
	
	// try standard function first
	if (rename(source_file, target_file) == EXIT_FAILURE) {
		// cross device move
		if (errno == EXDEV) {
			
			if (os_copy(source_file, target_file) == EXIT_FAILURE)
				return EXIT_FAILURE;

			return (remove(source_file));
			}
		}
	return 0;
	}

/*
 * read ASCII text from file, similar to cat
 */
static char *os_cat(const char *filename) {
	char *buffer = NULL;
	if (FILE *f = fopen(filename, "rb")) {
		struct stat st;
		if (fstat(fileno(f), &st) != EXIT_FAILURE) {
			size_t sz_file = st.st_size + 1;
			buffer = calloc(sz_file, sizeof(char));
			size_t sz_read = fread(buffer, sizeof(char), sz_file, f);
			buffer[sz_read] = 0;
			}
		fclose(f);
		}
	return buffer;
	}

/*
 * write ASCII text into file
 */
static size_t os_write_text_to_file(char *filename, char *buffer) {
	if (! buffer) 
		buffer = (char*) "";
	if (FILE *f = fopen(filename, "wb")) {
		size_t sz_size = strlen(buffer);
		size_t sz_file = fwrite(buffer, sizeof(char), sz_size, f);
		fclose(f);
		return sz_file;
		}
	else
		printf("Could not open %s: %s\n", filename, strerror(errno));
	return 0;
	}


// === database functions =====================================================

/*
 * write a property /value pair into the info table
 */
static bool db_update_info_property(const char *db_file, 
	const char *property, const char *value) {

	const char * sql_statement = " \
		insert or replace into info \
			(property, value) \
			values (?, ?)";

	sqlite3 *db;
	int result = EXIT_SUCCESS;
	if ((result = sqlite3_open(db_file, &db)) == 0) {
		sqlite3_stmt *_stmt;
		if ((result = sqlite3_prepare_v2(db, sql_statement, -1, &_stmt, NULL)) == 0) {

			int x = 1;	// query parameters start from 1
			sqlite3_bind_text (_stmt, x++, property, strlen(property), NULL);
			sqlite3_bind_text (_stmt, x++, value, strlen(value), NULL);

			if (sqlite3_step(_stmt) != SQLITE_DONE)
				result = EXIT_FAILURE;
			sqlite3_finalize(_stmt);
			}
		sqlite3_close(db);
		}

	return (result ? false : true);
	}

/*
 * add one entry to the adlist table
 */
static bool db_insert_blocklist_record(const char *db_file, const struct blocklist *plist) {

	const char *sql_statement = " \
		insert into adlist \
			(id, address, comment, date_updated, number, status, type) \
			values (?, ?, ?, ?, ?, ?, ?)";
	const char *comment = "Created by pihole-FTL gravity";

	sqlite3 *db;
	int result = 0;
	if ((result = sqlite3_open(db_file, &db)) == 0) {
		sqlite3_stmt *_stmt;
		if ((result = sqlite3_prepare_v2(db, sql_statement, -1, &_stmt, NULL)) == 0) {

			int x = 1;	// query parameters start from 1
			sqlite3_bind_int (_stmt, x++, plist->id);
			sqlite3_bind_text (_stmt, x++, plist->address, strlen(plist->address), NULL);
			sqlite3_bind_text (_stmt, x++, comment, strlen(comment), NULL);
			sqlite3_bind_int (_stmt, x++, time(NULL));
			sqlite3_bind_int (_stmt, x++, plist->count);
			sqlite3_bind_int (_stmt, x++, 1);	// test test test
			sqlite3_bind_int (_stmt, x++, plist->type);

			if (sqlite3_step(_stmt) != SQLITE_DONE)
				result = SQLITE_ERROR;
			sqlite3_finalize(_stmt);
			}
		sqlite3_close(db);
		}

	return (result ? false : true);
	}

/*
 * The blocklist configuration is stored in the gravity database. 
 * If a database does not (yet) exist, use a default configuration. 
 * Pi-hole default is defined in DEFAULT_LIST_PROVIDER
 */
static bool db_get_blocklists(struct config_data *pc) {

	const char * sql_statement = "select address, id, type from vw_adlist";

	// read from database, if database file exists
	char *db_file = pc->gravity_db_file;
	if (os_is_file(db_file)) {
		sqlite3 *db;
		int result = 0;
		if ((result = sqlite3_open(db_file, &db)) == 0) {
			sqlite3_stmt *stmt;
			if ((result = sqlite3_prepare_v2(db, sql_statement, -1, &stmt, NULL)) == 0) {

				while (sqlite3_step(stmt) == SQLITE_ROW) {
					struct blocklist item;
					int x = 0;	// columns in a result set start from 0
					item.address = strdup((const char*) sqlite3_column_text(stmt, x++));
					item.id = sqlite3_column_int(stmt, x++);
					item.type = sqlite3_column_int(stmt, x++);
					// status fields
					item.file_status = UNCHANGED;
					item.db_entry_exists = true;
					item.next = NULL;
					_add_listentry(pc, &item);
					}
				sqlite3_finalize(stmt);
				}
			sqlite3_close(db);
			}

		if (result)
			return false;
		}
	// use the default configuration
	else {
		struct blocklist item;
		item.id = 1;
		item.address = strdup(DEFAULT_LIST_PROVIDER);
		item.type = ADLIST_BLOCK;
		item.next = NULL;
		// status fields
		item.file_status = CHANGED_UPSTREAM;
		item.db_entry_exists = false;
		_add_listentry(pc, &item);
		}

	return true;
	}

/*
 *	read total and distinct row counts from gravity table
 *	result_array[0] contains the total row count,
 *	result_array[1] contains the number of distinct domains
 */
#define	ARRAY_SIZE(obj) sizeof(obj)/sizeof(obj[0])
static bool db_get_domain_count(const char *db_file, 
	int *result_array, 
	const unsigned array_size) {

	const char * sql_statement[] = {
		"SELECT COUNT(*) FROM gravity;",
		"SELECT COUNT(*) FROM (SELECT DISTINCT domain FROM gravity);",
		};

	sqlite3 *db;
	int result = SQLITE_OK;
	unsigned safe_size = min(array_size, ARRAY_SIZE(sql_statement));
	if ((result = sqlite3_open(db_file, &db)) == SQLITE_OK) {
		for ( unsigned i = 0 ; i < safe_size ; i++ ) {
			sqlite3_stmt *stmt;
			if ((result = sqlite3_prepare_v2(db, 
				sql_statement[i], -1, &stmt, NULL)) == SQLITE_OK) {
				if ((result = sqlite3_step(stmt)) == SQLITE_ROW) {
					result_array[i] = sqlite3_column_int(stmt, 0);
					result = SQLITE_OK;
					}
				sqlite3_finalize(stmt);
				}
			if (result != SQLITE_OK)
				break;
			}
		sqlite3_close(db);
		}

	return (result == SQLITE_OK ? true : false);
	}

/*
 *	read various row counts from domainlist table
 *	result_array returns domain allowed /denied and
 *	regex allowed /denied counts
 */
static bool db_get_domainlist_count(const char *db_file, 
	int *result_array, 
	const unsigned array_size) {

	const char * sql_statement = " \
		SELECT COUNT(*) FROM \
			(SELECT DISTINCT domain FROM domainlist WHERE enabled = ? AND type = ?);";

	sqlite3 *db;
	int result = SQLITE_OK;
	int enabled = 1;
	unsigned safe_size = min(array_size, 4U);
	if ((result = sqlite3_open(db_file, &db)) == SQLITE_OK) {
		// return four results, type progresses from 0 -> 3
		for ( unsigned i = 0 ; i < safe_size ; i++ ) {
			sqlite3_stmt *stmt;
			if ((result = sqlite3_prepare_v2(db, 
				sql_statement, -1, &stmt, NULL)) == SQLITE_OK) {
				int x = 1;	// query parameters start from 1
				sqlite3_bind_int (stmt, x++, enabled);
				sqlite3_bind_int (stmt, x++, (int) i);
				if ((result = sqlite3_step(stmt)) == SQLITE_ROW) {
					result_array[i] = sqlite3_column_int(stmt, 0);
					result = SQLITE_OK;
					}
				sqlite3_finalize(stmt);
				}
			if (result != SQLITE_OK)
				break;
			}
		sqlite3_close(db);
		}

	return (result == SQLITE_OK ? true : false);
	}

/*
 * batch-execute a self-contained sql script (without parameters)
 */
static int db_sql_exec_batch(const char *db_file, const char *sql_statement) {

	sqlite3 *db;
	char *err_message;
	int result = SQLITE_OK;
	if ((result = sqlite3_open(db_file, &db)) == SQLITE_OK) {
		if ((result = sqlite3_exec(db, 
			sql_statement, 
			NULL, 
			NULL, 
			&err_message)) != SQLITE_OK) {
			if (err_message) {
				printf("SQL error: %s\n", err_message);
				sqlite3_free(err_message);
				}
			}
		sqlite3_close(db);
		}

	return (result == SQLITE_OK ? EXIT_SUCCESS : EXIT_FAILURE);
	}

/*
 * read sql script from file and batch-execute it
 */
static int db_sql_exec_file(const char *db_file, const char *sql_file) {

	if (char *sql_statement = os_cat(sql_file)) {
		int result = db_sql_exec_batch(db_file, sql_statement);
		free(sql_statement);
		return result;
		}
	return EXIT_FAILURE;
	}


// === text parsers ===========================================================

/*
 *	split URI into protocol, login information, domain and path
 *	the domain value is copied to the original string buffer
 */
#define PROTOCOL_DELIMITER	"://"
#define LOGIN_DELIMITER	"@"
#define PATH_DELIMITER	"/"
#define LOCAL_DOMAIN	"localhost"
static char *_get_domain(char *uri) {
	static const char *local_domain = LOCAL_DOMAIN;

	// protocol qualifier
	if (char *p1 = strstr(uri, PROTOCOL_DELIMITER)) {
		*p1 = 0;
		char *protocol = uri;
		p1 += sizeof(PROTOCOL_DELIMITER) - 1;
		if (strcmp(protocol, "file") == 0) {
			strcpy(uri, local_domain);
			goto _get_domain_exit;
			}
		// skip optional login information
		char *p2;
		if ((p2 = strstr(p1, LOGIN_DELIMITER)))
			p2 += sizeof(LOGIN_DELIMITER) - 1;
		else
			p2 = p1;
		// separate domain information and path
		if (char *p3 = strstr(p2, PATH_DELIMITER)) {
			*p3 = 0;
			char *domain = p2;
			_strpcpy(uri, domain, p3);
			goto _get_domain_exit;
			}
		}

	uri[0] = 0;

_get_domain_exit:
	return uri;
	}

/*
 *	check if character is white space or cpmpares
 *	zo one of the characters in (optional) array
 */
static inline bool _ispattern(const char c, const char* pattern) {
	if (! isspace(c)) {
		if (pattern) {
			for( size_t u = 0 ; u < strlen(pattern)-1 ; u++ ) {
				if (pattern[u] == c)
					return true;		
				}
			}
		return false;
		}
	return true;
	}

/*
 *	python-style lstrip() function
 */
static inline char *_lstrip(char *string, const char *pattern) {
	int i = 0;
	int j = strlen(string)-1;
	if (i < j) {
		while (i < j && _ispattern(string[i], pattern))
			i += 1;
		if (i && j-i)
			memmove(string, string+i, j-i+1);
		int k = j-i ? j-i+1 : 0;
		string[k] = 0;
		}
	return string;
	}

/*
 *	python-style rstrip() function
 */
static inline char *_rstrip(char *string, const char *pattern) {
	int i = 0;
	int j = strlen(string)-1;
	while (j > i && _ispattern(string[j], pattern))
		j -= 1;
	int k = j-i ? j-i+1 : 0;
	string[k] = 0;
	return string;
	}

/*
 *	python-style strip() function
 */
static char *_strip(char *string, const char *pattern) {
	return _rstrip(_lstrip(string, pattern), pattern);
	}

/*
 *	python-style split() function
 */
static unsigned int _split(char *string, 
	const char delimiter, 
	const bool ignore_consecutive_delimiters,
	char **result) {

	// non-empty string
	if (string && string[0]) {
		char *curr = string;
		char *next;
		unsigned int index = 0;

		while ((next = strchr(curr, delimiter)) != NULL) {
			*next++ = 0;
			// ignore multiple consecutive delimiters
			if (ignore_consecutive_delimiters) {
				while (*next == delimiter)
					next += 1;
				}
			result[index++] = curr;
			curr = next;
			}
		// add final string
		result[index++] = curr;

		return index;
		}

	// for empty string, return []
	return 0;
	}

/*
 *	python-style join() function
 */
static char *_join(	char *string, const char delimiter,
	const char **array, const int array_size) {
	unsigned sz = 0;
	for ( int i = 0 ; i < array_size ; i++ ) {
		if (sz) {
			string[sz++] = delimiter;
			string[sz] = 0;
			}
		strcpy(string+sz, array[i]);
		sz += strlen(string+sz);
		}
	return string;
	}

/*
 *	check if address is a valid IP address
 *	strict checking rejects "0.0.0.0"
 */
static bool _is_ip_address(const char *address, const int mode) {

	// assume this is not an IP address
	if (! (isxdigit(address[0]) || address[0] == ':'))
		return false;

	char *fields[5];
	char *ip = strdup(address);

	// assume IPv4 address
	if(strchr(ip, '.')) {
		if (unsigned n = _split(ip, '.', false, fields)) {
			// exactly four fields must be specified, no range adress allowed
			if (n != 4)
				goto _ip_address_false;
			unsigned int binary_address = 0;
			for (unsigned int k = 0 ; k < n ; k++ ) {
				unsigned int u = (unsigned int) strtol(fields[k], NULL, 10);
				// four fields with size 8bit
				binary_address += (u << (8 * (4-1-k)));
				}
		#if _DEBUG_IP_PARSER
			for( unsigned int k = 0 ; k < n ; k++ )
				printf("%s.", fields[k]);
			printf(" %04x\n", binary_address);
		#endif	// _DEBUG_IP_PARSER
			if (mode != strict || binary_address != 0)
				goto _ip_address_true;
			}
		}

	// assume IPv6 address
	else if(strchr(ip, ':')) {
		// ignore zone index
		if(char *p = strchr(ip, '%'))
			*p = 0;
		// zero fields may be omitted
		if (unsigned n = _split(ip, ':', false, fields)) {
			unsigned long long binary_address = 0;
			for( unsigned int k = 0 ; k < n ; k++ ) {
				unsigned int u = (unsigned int) strtol(fields[k], NULL, 16);
				// routing prefix plus subnet id take up four fields with size 16bit
				// interface identifier part should not appear in routing tables
				binary_address += ((long long unsigned int) u << (16 * (4-1-k)));
				}
		#if	_DEBUG_IP_PARSING
			for( unsigned int k = 0 ; k < n ; k++ )
				printf("%s:", fields[k]);
			printf(" %u %llx\n", n, binary_address);
		#endif	// _DEBUG_IP_PARSER
			if (mode != strict || binary_address != 0)
				goto _ip_address_true;
			}
		}


_ip_address_false:
	free(ip);
	return false;
_ip_address_true:
	free(ip);
	return true;
	}

/*
 *	strip comments, remove everything except the domain name
 *	The original algorithm states:
 *		2) Remove carriage returns
 *		3) Remove lines starting with ! (ABP Comments)
 *		4) Remove lines starting with [ (ABP Header)
 *		5) Remove lines containing ABP extended CSS selectors 
 *		   ("##", "#$#", "#@#", "#?#") and Adguard JavaScript (#%#) preceded by a letter
 *		6) Remove comments (text starting with "#", include possible spaces before the hash sign)
 *		7) Remove leading tabs, spaces, etc. (Also removes leading IP addresses)
 *		8) Remove empty lines
 *
 *	This implements only a host file parser currently
 */
#define _is_comment(c)	((c) == '#' || (c) == '!')
static int _parse_line(char *line) {

	// remove leading white space
	// check for empty line
	// check for leading comment
	line = _lstrip(line, NULL);
	if (line[0] == 0)
		return 0;
	else if (_is_comment(line[0]))
		goto _parse_line_exit;

	// remove trailing white space
	_rstrip(line, NULL);

	// split line on blank and use the final token
	char *components[3];
	if (size_t n = _split(line, ' ', true, components)) {
		// valid result has two fields
		// filter valid ip address (e.g. localhost)
		// filter ip address in domain names
		if (n != 2 ||
			_is_ip_address(components[0], strict) ||
			_is_ip_address(components[1], loose))
			goto _parse_line_exit;
		// return last token
		memmove(line, components[n-1], strlen(components[n-1])+1);
		return strlen(line);
		}

_parse_line_exit:
		line[0] = 0;
		return 0;
	}

/*
 *	parse received file into internal domain list representation
 *	returns -1 on error, oterwise the number of copied entries
 */
static int _parse_blocklist( const char *source_file, const char *target_file ) {

	// leave the original target file intact until the transfer is concluded
	char temp_file[FN_SIZE];
	strcpy (temp_file, target_file);
	for( int i = strlen(temp_file) ; i > 0 ; i-- ) {
		if (temp_file[i] == '.') {
			temp_file[i] = '\0';
			break;
			}
		}
	strcat(temp_file, ".tmp");

	char *buffer = calloc(1, STD_BLK_SIZE);
	if (buffer == NULL)
		return EXIT_FAILURE;

	int error = 0;
	int line_counter = 0;
	
	if (FILE *s = fopen(source_file, "r")) {
		if (FILE *t = fopen(temp_file, "w")) {
			while ((fgets(buffer, STD_BLK_SIZE, s)) != NULL) {
				// ignore empty lines
				if (size_t sz = _parse_line(buffer)) {
					// add line feed
					buffer[sz++] = '\n';
					if (fwrite(buffer, 1, sz, t) != sz) {
						error = EXIT_FAILURE;
						break;
						}
					line_counter += 1;
					}
				}
			fclose(t);
			}
		fclose(s);
		}

	free (buffer);

	if (! error)
		os_rename(temp_file, target_file);

	return (error ? error : line_counter);
	}

/*
 * calculate checksum of file
 */
static unsigned char *_sha1_sum( const char *filename, unsigned char *digest ) {

	struct stat st;
	if (stat(filename, &st) == EXIT_FAILURE)
		return NULL;
	size_t block_size = st.st_blksize;

	if (char *buffer = calloc(1, block_size)) {

		SHA_CTX context;
		if (SHA1_Init(&context)) {


			if (FILE *f = fopen(filename, "rb")) {
				size_t sz;
				while ((sz = fread(buffer, 1, block_size, f)) > 0) {
					if (! SHA1_Update(&context, buffer, sz)) {
						fclose(f);
						free(buffer);
						return NULL;
						}
					}
				fclose(f);
				}

			if (! SHA1_Final(digest, &context)) {
				free(buffer);
				return NULL;
				}
			}
		free(buffer);
		}

	return digest;
	}

/*
 * format sha_sum output
 */
static char *_digest_to_hex(char *output_buffer, 
	const unsigned char *digest, const size_t digest_size, 
	const char *filename) {

	const char *hex = "0123456789abcdef";
	char *p = output_buffer;
	for( size_t i = 0 ; i < digest_size ; i++ ) {
		*p++ = hex[(digest[i]>>4) & 0xf];
		*p++ = hex[digest[i] & 0xf];
		}
	*p++ = ' ';
	*p++ = ' ';
	strcpy(p, filename);

	return output_buffer;
	}


// === linked list manipulation ===============================================

static void _add_listentry(struct config_data *pc, 
	const struct blocklist *pi) {

	struct blocklist **pnext = &pc->vw_adlist;
	if (pc->vw_adlist) {
		struct blocklist *head = pc->vw_adlist;
		while (head->next)
			head = head->next;
		pnext = &head->next;
		}
	(*pnext) = (struct blocklist *) calloc(1, sizeof(struct blocklist));
	(*pnext)->address = pi->address;	// consume allocated string
	(*pnext)->id = pi->id;
	(*pnext)->type = pi->type;
	(*pnext)->file_status = pi->file_status;
	(*pnext)->db_entry_exists = pi->db_entry_exists;
	// convenience entry
	if (pi->address)
		(*pnext)->domain = _get_domain(strdup(pi->address));
	}

static struct blocklist *_get_listentry(const struct config_data *pc, 
	const int id,
	const char *domain) {

	struct blocklist *curr = pc->vw_adlist;
	while (curr) {
		if (curr->id == id &&
			strcmp(curr->domain, domain) == 0)
			return curr;
		curr = curr->next;
		}
	return NULL;
	}


// === pihole-FTL functions  ==================================================

/*
 * read configuration values from internal database
 */
static bool ftl_get_configuration(struct config_data *pc) {

	// read from configuration
	readFTLconf(&config, false);
	strncpy(pc->gravity_db_file, config.files.gravity.v.s, FN_SIZE-1);
	pc->gravity_db_file[FN_SIZE-1] = 0;
	strncpy(pc->gravity_tempdir, config.files.gravity_tmp.v.s, FN_SIZE-1);
	pc->gravity_tempdir[FN_SIZE-1] = 0;
	// filled from db_file
	strncpy(pc->gravity_directory, pc->gravity_db_file, FN_SIZE-1);
	pc->gravity_directory[FN_SIZE-1] = 0;
	dirname(pc->gravity_directory);	// modifies parameter
	strncpy(pc->gravity_db_tmpfile, pc->gravity_db_file, FN_SIZE-6);
	pc->gravity_db_tmpfile[FN_SIZE-6] = 0;
	strcat(pc->gravity_db_tmpfile, "_temp");
	// filled from gravity_directory
	strncpy(pc->gravity_db_oldfile, pc->gravity_directory, DN_SIZE);
	pc->gravity_db_oldfile[DN_SIZE] = 0;
	strcat(pc->gravity_db_oldfile, "/gravity_old.db");
	strncpy(pc->gravity_db_backup_dir, pc->gravity_directory, DN_SIZE);
	pc->gravity_db_backup_dir[DN_SIZE] = 0;
	strcat(pc->gravity_db_backup_dir, "/gravity_backups");
	// filled from gravity_db_backup_dir
	strncpy(pc->gravity_db_backup_file, pc->gravity_db_backup_dir, DN_SIZE);
	pc->gravity_db_backup_file[DN_SIZE] = 0;
	strcat(pc->gravity_db_backup_file, "/gravity.db");
	// filled from gravity_directory
	strncpy(pc->list_cache_directory, pc->gravity_directory, DN_SIZE);
	pc->list_cache_directory[DN_SIZE] = 0;
	strcat(pc->list_cache_directory, "/listsCache");

	// sources
	pc->vw_adlist = NULL;
	
	return true;
	}

/*
 * import blocklist into database
 */
static int ftl_import_domains(char *list_file, 
	char *db_file, int list_id, int list_type) {

	char id[5] = {};
	const bool antigravity = (list_type == ADLIST_ALLOW ? true : false);
	return gravity_parseList(list_file, 
		db_file, 
		i2str(id, list_id), 
		false, 
		antigravity);
	}


// === update /import functions ===============================================

/*
 * callback function for incoming curl responses
 */
static size_t response_callback(void *ptr, size_t size, size_t count, void *userdata)
{
	FILE *buffered_stream = (FILE *) userdata;
	if (buffered_stream) {
		return fwrite(ptr, size, count, buffered_stream);
		}
	return 0;
	}

/*
 * download single target and update versioning information
 */
static bool _download_single_list(struct blocklist *plist, 
	char *fn_list, 
	char *fn_temp) {

	bool result = false;
	const char *ce[] = {fn_list, LIST_ETAG};
	char *fn_etag = _join(calloc(FN_SIZE, sizeof(char)), '.', ce, ARRAY_SIZE(ce));
	const char *cc[] = {fn_list, LIST_CHKSUM};
	char *fn_chks = _join(calloc(FN_SIZE, sizeof(char)), '.', cc, ARRAY_SIZE(cc));

	char *etag = os_cat(fn_etag);

	curl_global_init(CURL_GLOBAL_DEFAULT);

	if (CURL *session = curl_easy_init()) {

		/* open file for writing */
		if (FILE *f = fopen(fn_temp, "wb")) {

			curl_easy_setopt(session, CURLOPT_URL, plist->address);
			curl_easy_setopt(session, CURLOPT_ACCEPT_ENCODING, "");	// accept all builtin encodings
			curl_easy_setopt(session, CURLOPT_WRITEFUNCTION, response_callback);
			curl_easy_setopt(session, CURLOPT_WRITEDATA, f);
			curl_easy_setopt(session, CURLOPT_VERBOSE, 0L);	// full protocol output

			// set an if-none-match header
			struct curl_slist *hdr = NULL;
			if (etag) {
				char header_text[FN_SIZE];
				sprintf(header_text, "%s: %s", "If-None-Match", etag);
				hdr = curl_slist_append(hdr, header_text);
				curl_easy_setopt(session, CURLOPT_HTTPHEADER, hdr);
				}

			if (CURLcode cr = curl_easy_perform(session) != CURLE_OK) {
				printf("Curl execution error: %u\n", cr);
				result = false;
				fclose(f);
				goto _download_single_list_exit;
				}

			fclose(f);

			/*
			 *	process results
			 */

			long response_code = 0;
			if (CURLcode cr = curl_easy_getinfo(session, 
				CURLINFO_RESPONSE_CODE, &response_code)!= CURLE_OK) {
				printf("Curl getinfo error: %u\n", cr);
				result = false;
				goto _download_single_list_exit;
				}

			struct curl_header *ptag = NULL;
			if (CURLHcode ch = curl_easy_header(session, 
				"etag", 0, CURLH_HEADER, -1, &ptag) != CURLHE_OK) {
				printf("Curl header error: %u\n", ch);
				result = false;
				goto _download_single_list_exit;
				}

			switch(response_code) {
				case 200:	// OK
					// parse blocklist file into domain list file
					if ((plist->count = _parse_blocklist(fn_temp, fn_list)) == EXIT_FAILURE) {
						printf("Moving %s to %s failed: %s\n", fn_temp, fn_list, strerror(errno));
						result = false;
						goto _download_single_list_exit;
						}
					_set_file_permissions(fn_list);
					// write etag
					if (ptag) {
						char *tag_value = ptag->value;
						// omit weak validation marker
						if (strncmp(tag_value, "W/", 2) == 0)
							tag_value += 2;
						os_write_text_to_file(fn_etag, tag_value);
						_set_file_permissions(fn_etag);
						}
					// create SHA1 value
					unsigned char sha1_digest[SHA_DIGEST_LENGTH];
					if (! _sha1_sum(fn_list, sha1_digest)) {
						printf("SHA digest failed for %s\n", fn_list);
						result = false;
						goto _download_single_list_exit;
						}
					char sha_sum[FN_SIZE];
					os_write_text_to_file(fn_chks, 
						_digest_to_hex(sha_sum, sha1_digest, sizeof(sha1_digest), fn_list));
					_set_file_permissions(fn_chks);
					plist->file_status = CHANGED_UPSTREAM;
					printf("Downloaded new version: %s\n", fn_list);
					break;
				case 304:	// not modified
#if	_FAKE_CHANGED_UPSTREAM
					plist->file_status = CHANGED_UPSTREAM;
					printf("Fake change: %s\n", fn_list);
#else
					plist->file_status = UNCHANGED;
					printf("Unchanged: %s\n", fn_list);
#endif
					break;
				default:
					printf("HTTP error: %ld\n", response_code);
					// cached list exists
					if (os_is_file(fn_list)) {
						printf("Use existing version: %s\n", fn_list);
						plist->file_status = FAILED_CACHED;
						}
					else
						plist->file_status = FAILED_MISSING;
					result = false;
					goto _download_single_list_exit;
				}

			plist->filename = strdup(fn_list);
			result = true;

_download_single_list_exit:
			curl_easy_cleanup(session);

			if (hdr)
				curl_slist_free_all(hdr);

			// file is closed, may have been moved to permanent location
			remove(fn_temp);
			}
		}

	if (etag)
		free(etag);
	free(fn_etag);
	free(fn_chks);
	return result;
	}

/*
 * download blocklists defined in configdata.vw_adlist
 */
static bool _download_blocklists(struct config_data *pc) {

	// make sure the download directory exists
	if (! os_is_directory(pc->list_cache_directory) &&
		mkdir(pc->list_cache_directory, DIR_ACCESS) != EXIT_SUCCESS) {
		printf("can't create directory %s\n", pc->list_cache_directory);
		return false;
		}

	struct blocklist *plist = pc->vw_adlist;
	while(plist) {
		char base_file_name[FN_SIZE*2];
		sprintf(base_file_name,
			"%s/%s.%d.%s.%s",
			pc->list_cache_directory,
			LIST_PREFIX,
			plist->id,
			plist->domain,
			LIST_POSTFIX
			);
		char temp_file_name[FN_SIZE*2];
		sprintf(temp_file_name,
			"%s/%s.%d.%s.%s",
			pc->gravity_tempdir,
			"list",
			plist->id,
			plist->domain,
			"tmp"
			);
		printf("Download blocklist from %s\n", plist->domain);
		if (! _download_single_list(plist, base_file_name, temp_file_name)) {
			printf("could not download: %s\n", plist->address);
			return false;
			}

		plist = plist->next;
		}

	return true;
	}

/*
 * import changed blocklists into database domains table
 */
static bool _import_blocklists(struct config_data *pc) {

	struct blocklist *plist = pc->vw_adlist;
	while(plist) {
		if (plist->db_entry_exists == false) {
			// import function prints progress
			if (! db_insert_blocklist_record(pc->gravity_db_tmpfile, plist)) {
				printf("Data entry failed: %s\n", plist->address);
				return false;
				}
			}
		if (plist->file_status == CHANGED_UPSTREAM) {
			printf("Start import: %s\n", plist->address);
			if (ftl_import_domains(plist->filename, 
				pc->gravity_db_tmpfile, 
				plist->id, 
				plist->type) != EXIT_SUCCESS) {
				printf("Import failed: %s\n", plist->address);
				return false;
				}
			}
		plist = plist->next;
		}
	return true;
	}

/*
 * remove blocklist files from the list cache
 * list files that are not contained in the database will be deleted
 * if the parameter force is set to true, 
 * all list files will be deleted to force a download
 */
static bool _clear_list_cache(const struct config_data *pc, const bool force) {

	char path[FN_SIZE*2];
	char *domain = path + FN_SIZE;
	if( DIR *d = opendir(pc->list_cache_directory) ) {
		struct dirent *e;
		while( (e = readdir(d)) != NULL ) {
			strcpy(path, e->d_name);
			char *components[7] = {};
			unsigned n = _split(path, '.', false, components);
			// strip status file name endings
			if (strcmp(components[n-1], LIST_ETAG) == 0 ||
				strcmp(components[n-1], LIST_CHKSUM) == 0)
				n -= 1;
			// process only "list.*.domains" files
			if (strcmp(components[0], LIST_PREFIX) == 0 &&
				strcmp(components[n-1], LIST_POSTFIX) == 0) {
				int id = (int) strtol(components[1], NULL, 10);
				domain = _join(domain, '.', (const char **) components+2, n-3);
				if (force ||
					_get_listentry(pc, id, domain) == NULL) {
					sprintf(path, "%s/%s", pc->list_cache_directory, e->d_name);
					if (remove(path) != 0) {
						printf("can'tremove %s: %s\n", path, strerror(errno));
						return false;
						}
					}
				}
			}
		closedir(d);
		}
	return true;
	}

/*
 * selectively copies data from the existing database to the new one
 */
static bool _copy_database(const struct config_data *pc) {

	/*
	 * if the old database exists, copy data to the temporary database
	 */
	#define TOKEN1	"ATTACH DATABASE"
	#define TOKEN2	"AS OLD"
	int error = EXIT_SUCCESS;
	const char *db_file = configuration.gravity_db_file;
	const char *db_tmpfile = configuration.gravity_db_tmpfile;
	if (os_is_file(db_file)) {
		const char *sql_file = PIHOLE_SCRIPTDIR "/" GRAVITY_DBCOPY_SCRIPT;
		char *sql_statement = os_cat(sql_file);
		if (! sql_statement) {
			printf("Could not read sql file %s\n", sql_file); 
			error = EXIT_FAILURE;
			goto _copy_database_exit;
			}
		char *token1 = strstr(sql_statement, TOKEN1);
		char *token2 = strstr(sql_statement, TOKEN2);
		if (! token1 || ! token2) {
			printf("Missing %s ... %s statement in sql file %s\n", 
				TOKEN1, TOKEN2, sql_file); 
			free(sql_statement);
			error = EXIT_FAILURE;
			goto _copy_database_exit;
			}
		token1 += strlen(TOKEN1);
		char db_name[FN_SIZE];
		_strpcpy(db_name, token1, token2);
		_strip(db_name, "\'\"");
		if (strcmp(db_name, db_file) != 0) {
			printf("Using gravity database %s\n", db_file); 
			size_t old_size = strlen(db_name);
			size_t new_size = strlen(db_file);
			size_t total_size = strlen(sql_statement) - old_size + new_size;
			size_t tail_size = strlen(token2);
			if (new_size > old_size) {
				sql_statement = realloc(sql_statement, total_size + 1);
				}
			memmove(token2 - old_size + new_size, token2, tail_size);
			size_t sz = sprintf(token1, " '%s'", db_file);
			token1[sz] = ' ';	// remove the just added '\0'
			sql_statement[total_size] = 0;	// add the final '\0'
			}
		if ((error = db_sql_exec_batch(db_tmpfile, sql_statement)) != EXIT_SUCCESS ) {
			printf("SQL statement %s failed with error %d\n", sql_file, error); 
			free(sql_statement);
			goto _copy_database_exit;
			}
		free(sql_statement);
		}

_copy_database_exit:
	return (error == EXIT_SUCCESS ? true : false);
	}

/*
 * if backup directory exists, rotate backup files
 */
#define MAX_BACKUPS 10
static bool _rotate_backups(const struct config_data *pc) {
	
	if (os_is_file(pc->gravity_db_backup_file)) {
		const char *base_name = pc->gravity_db_backup_file;
		char fn_name[2][FN_SIZE];
		for ( int i = MAX_BACKUPS-1 ; i > 1 ; i-- ) {
			sprintf(fn_name[0], "%s.%d", base_name, i);
			sprintf(fn_name[1], "%s.%d", base_name, i+1);
			if (os_is_file(fn_name[1]) &&
				! os_remove(fn_name[1]))
				return false;
			if (! os_rename(fn_name[0], fn_name[1]))
				return false;
			}
		}
	return true;
	}

static bool _swap_databases(const struct config_data *pc) {

	if (os_is_file(pc->gravity_db_file)) {

		// keep copy of current database
		os_remove(pc->gravity_db_oldfile);
		if (os_vfs_avail(pc->gravity_directory)/2 > os_fsize(pc->gravity_db_file) &&
			os_copy(pc->gravity_db_file, pc->gravity_db_oldfile) != EXIT_SUCCESS)
			printf("cannot copy %s to %s: %s\n", 
				pc->gravity_db_file, 
				pc->gravity_db_oldfile, 
				strerror(errno));

		/* 
		 *	compact and backup current database
		 */

		if (! _rotate_backups(pc)) {
			printf("Backup rotation failed\n");
			return false;
			}

		const char *sql_statement = " \
			PRAGMA busy_timeout = 30000; \
			DROP TABLE IF EXISTS gravity; \
			DROP TABLE IF EXISTS antigravity; \
			VACUUM;";
		int error;
		const char *db_file = pc->gravity_db_file;
		if ((error = db_sql_exec_batch(db_file, sql_statement)) != EXIT_SUCCESS) {
			printf("Compaction of database %s failed: error %d\n", db_file, error);
			return false;
			}
		
		const char *backup_dir = pc->gravity_db_backup_dir;
		if (! os_is_directory(backup_dir) &&
			mkdir(backup_dir, DIR_ACCESS) != EXIT_SUCCESS) {
			printf("can't create directory %s: %s\n", 
				backup_dir,
				strerror(errno));
			return false;
			}
	
		char fn_name[FN_SIZE];
		sprintf (fn_name, "%s.%d", pc->gravity_db_backup_file, 1);
		if (os_rename(pc->gravity_db_file, fn_name) != EXIT_SUCCESS) {
			printf("cannot rename %s to %s: %s\n", 
				pc->gravity_db_file, 
				fn_name,
				strerror(errno));
			return false;
			}
		}

	if (os_rename(pc->gravity_db_tmpfile, pc->gravity_db_file) != EXIT_SUCCESS) {
		printf("cannot rename %s to %s: %s\n", 
			pc->gravity_db_tmpfile, 
			pc->gravity_db_file, 
			strerror(errno));
		return false;
		}

	return true;
	}

static void _gravity_cleanup(const struct config_data *pc) {

	const char *db_file = pc->gravity_db_tmpfile;
	if (os_is_file(db_file))	
		os_remove(db_file);	

	_clear_list_cache(pc, false);

	struct blocklist *curr = pc->vw_adlist;
	while (curr) {
		if (curr->address)
			free(curr->address);
		if (curr->domain)
			free(curr->filename);
		if (curr->domain)
			free(curr->filename);
		curr = curr->next;
		}
	}


// === top level functions ====================================================

/*
 * print usage message to stdout
 */
static void help_message(char *prg)
{
	printf("Usage: %s <options>\n", prg);
	printf("where options are:\n");
	printf("  -f  --force         force deletion of existing database\n");
	printf("  -h  --help          show usage message\n");
	printf("  -r  --repair {recover,recreate} [force]\n");
	printf("        recover       repair a damaged gravity database file\n");
	printf("        recover force attempt repair even if no damage detected\n");
	printf("        recreate      create a new gravity database\n");
	printf("  -t  --timeit        show execution times for certain steps\n");
	printf("  -u  --upgrade       upgrade gravity database\n");
}

#if _PRINT_DEBUG_OUTPUT
static void __dump_cfg__(struct config_data *pc)
{
	#define PRINT_PARAMETER(a)	(printf("%s = %s\n", #a, a))
	PRINT_PARAMETER(pc->gravity_db_file);
	PRINT_PARAMETER(pc->gravity_tempdir);
	PRINT_PARAMETER(pc->gravity_directory);
	PRINT_PARAMETER(pc->gravity_db_tmpfile);
	PRINT_PARAMETER(pc->gravity_db_oldfile);
	PRINT_PARAMETER(pc->gravity_db_backup_dir);
	PRINT_PARAMETER(pc->gravity_db_backup_file);
	PRINT_PARAMETER(pc->list_cache_directory);

	printf("list sources:\n");
	struct blocklist *head = pc->vw_adlist;
	while( head ) {
		printf("%4d %s %d\n", head->id, head->address, head->type);
		head = head->next;
	}
}

#define print_configuration(c) __dump_cfg__(c)
#else
#define print_configuration(c)
#endif // _PRINT_DEBUG_OUTPUT

#if _PRINT_DEBUG_OUTPUT
static void __dump_flags__(void) {
	char options[256] = { "(none)" };
	unsigned w = 0;
	if (force_recover)
		w += sprintf(options+w, "%s ", "force_recover"); 
	if (force_deletion)
		w += sprintf(options+w, "%s ", "force_deletion"); 
	if (display_timing)
		w += sprintf(options+w, "%s ", "display_timing"); 
	PRINT_PARAMETER(options); 
	}
#define print_flags() __dump_flags__()
#else
#define print_flags()
#endif // _PRINT_DEBUG_OUTPUT


/*
 * implements gravity --update
 */
static bool gravity_update(void) {

	bool result = false;
	int error = EXIT_SUCCESS;

	printf("Rebuild the gravity database\n");

	printf("Create new gravity database\n"); 
	const char *db_tmpfile = configuration.gravity_db_tmpfile;
	const char *sql_file = PIHOLE_SCRIPTDIR "/" GRAVITY_DBSCHEMA_SCRIPT;
	if ((error = db_sql_exec_file(db_tmpfile, sql_file)) != 0 ) {
		printf("Database creation failed: error %d\n", error); 
		return false;
		}
	_set_file_permissions(db_tmpfile);

	/*
	 * this should go to database switch
	 */
	printf("Copy data from the existing database\n"); 
	if(! _copy_database(&configuration)) {
		printf("Data copy failed\n"); 
		result = false;
		goto gravity_update_exit;
		}

	/*
	 * (not implemented) wait for DNS resolution to be available
	 */

	printf("Download blocklists\n"); 
	if (! _download_blocklists(&configuration)) {
		printf("Blocklist download failed\n"); 
		result = false;
		goto gravity_update_exit;
		}

	printf("Import blocklists into database\n"); 
	if (! _import_blocklists(&configuration)) {
		printf("Blocklist import failed\n"); 
		result = false;
		goto gravity_update_exit;
		}

	// insert or update timestamp
	#define PROPERTY_UPDATED "updated"
	char time_now[20] = {};
	if (! db_update_info_property(db_tmpfile, 
		PROPERTY_UPDATED, lli2str(time_now, time(NULL)))) {
		printf("Update timestamp property failed\n"); 
		result = false;
		goto gravity_update_exit;
		}

	_set_file_permissions(db_tmpfile);

	printf("Create index on gravity table\n");
	const char *sql_statement = " \
		CREATE INDEX idx_gravity \
			ON gravity (domain, adlist_id);";
	if ((error = db_sql_exec_batch(db_tmpfile, sql_statement)) != EXIT_SUCCESS ) {
		printf("Index creation failed: error %d\n", error);
		result = false;
		goto gravity_update_exit;
		}

	int gravity_count[] = { -1, -1 };
	if (db_get_domain_count(db_tmpfile, gravity_count, 2)) {
		printf("\n");
		printf("%18s  %-10s %s\n", "", 
			"domains", "unique domains");
		printf("%18s  %-10d %d\n", 
			"gravity", gravity_count[0], gravity_count[1]);
		printf("\n");
		}
	int domainlist_count[] = { 0, 0, 0, 0 };
	if (db_get_domainlist_count(db_tmpfile, domainlist_count, 4)) {
		printf("%18s  %-10s %s\n", "", "allowed", "denied");
		printf("%18s  %-10d %d\n", 
			"domainlist domains", domainlist_count[0], domainlist_count[1]);
		printf("%18s  %-10d %d\n", 
			"filters", domainlist_count[0], domainlist_count[1]);
		printf("\n");
		}

	// insert or update total count
	#define PROPERTY_COUNT "gravity_count"
	char _gravity_count[10] = {};
	if (! db_update_info_property(db_tmpfile, 
		PROPERTY_COUNT, i2str(_gravity_count, gravity_count[1]))) {
		printf("Update gravity_count property failed\n");
		result = false;
		goto gravity_update_exit;
		}

	printf("Optimize gravity database\n");
	sql_statement = " \
		PRAGMA analysis_limit=0; \
		ANALYZE";
	if ((error = db_sql_exec_batch(db_tmpfile, sql_statement)) != EXIT_SUCCESS ) {
		printf("Database optimization failed: error %d\n", error);
		result = false;
		goto gravity_update_exit;
		}

	printf("Backup and swap databases\n");
	if (! _swap_databases(&configuration)) {
		printf("Database replacement failed\n");
		result = false;
		goto gravity_update_exit;
		}

gravity_update_exit:

	_gravity_cleanup(&configuration);

	return result;
	}

/*
 * parse command line options into internal variables
 */
static int _parse_args(int argc, char *argv[])
{
	if(argc > 1) {
		for( int i = 1 ; i < argc; i++ ) {
			char *cmd = argv[i];
			// options
			if( strcmp(cmd, "-f") == 0 || strcmp(cmd, "--force") == 0 )
				force_deletion = true;
			else if( strcmp(cmd, "-h") == 0 || strcmp(cmd, "--help") == 0 ) {
				help_message(argv[0]);
				exit(EXIT_SUCCESS);
			}
			else if( strcmp(cmd, "-t") == 0 || strcmp(cmd, "--timeit") == 0 )
				display_timing = true;
			else if( strcmp(cmd, "-u") == 0 || strcmp(cmd, "--upgrade") == 0 ) {
				// conflicting activity
				if( command )
					return i;
				command = UPGRADE;
			}
			// commands
			else if( strcmp(cmd, "-r") == 0 || strcmp(cmd, "--repair") == 0 ) {
				// next verb should be repair or recover
				if( i+1 < argc && strcmp(argv[i+1], "repair") == 0 ) {
					// conflicting activity
					if( command )
						return i;
					command = REPAIR;
					i += 1;
				}
				else if( i+1 < argc && strcmp(argv[i+1], "recover") == 0 ) {
					// conflicting activity
					if( command )
						return i;
					command = RECOVER;
					i += 1;
					// recover has optional subcommand
					if( i+1 < argc && strcmp(argv[i+1], "force") == 0 ) {
						force_recover = true;
						i += 1;
					}
				}
			else
				return i;
			}
		else
			return i;
		}
		return 0;
	}
	help_message(argv[0]);
	exit(EXIT_SUCCESS);
}


// === module entry ===========================================================

/*
 * the entry function of the gravity module
 */
int gravity_main(const int argc, char *argv[])
{
	// enable output to stdout
//	cli_mode = true;
	log_ctrl(false, true);

	if( int failed_argument = _parse_args(argc, argv) != 0 ) {
		printf("Argument error: %s\n", argv[failed_argument]);
		exit(EXIT_FAILURE);
	}

	if( ! command ) {
		printf("Nothing to do, exiting.\n");
		exit(EXIT_FAILURE);
	}

	print_flags();


	if( ! ftl_get_configuration(&configuration) ) {
		printf("Retrieving configuration values failed\n"); 
		exit(EXIT_FAILURE);
	}

	if( ! db_get_blocklists(&configuration) ) {
		printf("Retrieving blocklist configuration failed\n"); 
		exit(EXIT_FAILURE);
	}

	print_configuration(&configuration);

	// this forces download of configured adlists
	if (force_deletion) {
		printf("Clear existing list cache %s\n", configuration.list_cache_directory); 
		if( ! _clear_list_cache(&configuration, force_deletion) )
			exit(EXIT_FAILURE);
		}

	// ungünstiger Zeitpunkt, sollte vielleicht im Rahmen des cleanups passieren ... 
	// old backup is removed prior to any database activity
	if( ! os_remove(configuration.gravity_db_oldfile) )
		exit(EXIT_FAILURE);

	if( command == REPAIR ) {
		printf("Gravity database repair not implemented\n");
	}
	else if( command == RECOVER ) {
		printf("Gravity database recover not implemented \n");
	}
	else if( command == UPGRADE ) {
		gravity_update();
	}

	exit(EXIT_SUCCESS);
}
