/* Pi-hole: A black hole for Internet advertisements
 *  (c) 2017 Pi-hole, LLC (https://pi-hole.net)
 *  Network-wide ad blocking via your own hardware.
 *
 *	Color table
 *	excerpt from advanced/scripts/COL_TABLE
 *
 *  This file is copyright under the latest version of the EUPL.
 *  Please see LICENSE file for your rights under this license.
 */

#define COL_BOLD "\033[1m"
#define COL_NC "\033[0m"
#define COL_GRAY "\033[37m"
#define COL_RED "\033[91m"
#define COL_GREEN "\033[32m"
#define COL_YELLOW "\033[33m"
#define COL_BLUE "\033[94m"
#define COL_PURPLE "\033[95m"
#define COL_CYAN "\033[96m"

#define COL_TICK "[" COL_GREEN "✓" COL_NC "]"
#define COL_CROSS "[" COL_RED "✗" COL_NC "]"
#define INFO "[i]"
#define QST "[?]"
#define OVER "\r\033[K"

static const char* _bld = "";
static const char* NC = "";
static const char* GY = "";
static const char* RD = "";
static const char* GN = "";
static const char* YL = "";
static const char* BL = "";
static const char* PR = "";
static const char* CY = "";

static const char *TICK = "[✓]";
static const char *CROSS = "[✗]";

static inline void set_termcolor(void) {
	if (isatty(fileno(stdout))) {
		if (const char *terminal = getenv("TERM")) {
			if (strcmp(terminal, "dumb") != 0) {
				if (! getenv("NO_COLOR")) {
					_bld = COL_BOLD;
					NC = COL_NC;
					GY = COL_GRAY;
					RD = COL_RED;
					GN = COL_GREEN;
					YL = COL_YELLOW;
					BL = COL_BLUE;
					PR = COL_PURPLE;
					CY = COL_CYAN;

					TICK = COL_TICK;
					CROSS = COL_CROSS;
					}
				}
			}
		}
	}
