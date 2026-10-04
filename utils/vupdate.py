#!/bin/python

'''
	Auto-update Buildroot packages
'''

from glob import glob
import json
import os
from re import match, search
from subprocess import run
import sys

import requests

BUILDROOT_DIR = '~/buildroot'
EXTERNAL_DIR = '~/br2-external'
DOWNLOAD = 'dl'
PACKAGE = 'package'
TIMEOUT = 10
DEBUG_LEVEL = 0	# set to 1 to enable DEBUG_LEVEL output, to 2 to use TEST_PKG_NAMES

TEST_PKG_NAMES = [
	'libopenssl',
	'python3',
	]

FORCE_EXCLUSION = [
	# version is configurable through kconfig
	'binutils',
	# build system changed, do not update now
	'fakeroot',
	# symlink to gcc
	'gcc-bare-metal',
	# version handling is non-standard
	'ncurses',
	'sqlite',

	# buildroot depends on a specific version
	'patchelf',

	# breaks build
	'libopenssl',
	'libtool',
	'pkgconf',
	]

# would be incomplete due to missing exec() call
FORCE_INCLUSION = [
	# virtual package
	'fftw',
	]

# use PyPI provider for these packages
PYTHON_PACKAGES = [
	'meson',
	'ninja',
	]

EXCLUDE_PROVIDERS = [
	'CRAN (R)',
	'crates.io',
	'GitLab',
	'Rubygems',
	]

# used for release-monitoring.org
PACKAGE_PROJECT_MAP = {
	'exfat': 'fuse-exfat',
	'libfuse3': 'libfuse',
	'libidn2': 'libidn',
	'pihole-pi-hole': 'pi-hole',
	'pypa-build': 'build',
	'python3': 'python',
	'uclibc': 'uclibc-ng',
	}

# used for hashing
PACKAGE_SOURCE_MAP = {
	'libopenssl': 'openssl',
	'libtalloc': 'talloc',
	'python3': 'Python',
	}

class BuildrootPackage:
	'''
		buildroot package information, retrieved from release-monitoring.org and github tags
	'''

	_release_monitoring_url = "https://release-monitoring.org/api/v2/projects/"
	_session = None

	def __init__(self, package: dict):
		self.package = package

	@classmethod
	def from_package(cls, name: str):
		''' initialize project from buildroot configuration '''
		pkg = {}
		pkg['name'] = name
		fb = cls._makefile_path(name, BUILDROOT_DIR)
		fx = cls._makefile_path(name, EXTERNAL_DIR)
		# no makefile
		if not fb and not fx:
			return None
		# br2-external path overrides buildroot path
		pkg['path'] = fx if fx else fb
		pkg['override'] = bool(fb) and bool(fx)
		pkg['_br_version'], pkg['_version_values'] = \
			cls._get_buildroot_version(pkg['name'], pkg['path'])
		pkg['project'] = cls._map_name(PACKAGE_PROJECT_MAP, pkg['name'])
		pkg['source'] = cls._map_name(PACKAGE_SOURCE_MAP, pkg['name'], ch='_')
		# no version info in makefile
		if not pkg['_br_version']:
			return None
		return cls(pkg)

	@staticmethod
	def _map_name(_map: dict, name: str, ch='-')-> str:
		''' map names if found in dictionary '''
		if name.startswith('python-'):
			return ch.join(name.split('-')[1:])
		return _map[name] if name in _map else name

	@staticmethod
	def _makefile_path(pkg_name, root_path) -> str:
		''' find the dominant makefile for this project '''
		f = os.path.join(os.path.expanduser(root_path), PACKAGE, pkg_name, pkg_name + '.mk')
		if os.path.isfile(f):
			if pkg_name in FORCE_INCLUSION and root_path == BUILDROOT_DIR:
				return f
			with open(f, 'r', encoding='UTF8') as makefile:
				for line in makefile:
					if match(r'\$\(eval \$\([a-z-]+\)\)', line):
						return f
		return ''

	@staticmethod
	def _get_buildroot_version(pkg_name: str, file_name: str):
		''' read the package version from the Buildroot makefile '''
		version_string = f"{pkg_name.replace('-','_').upper()}_VERSION"
		version_values = {}
		if DEBUG_LEVEL:
			print(f"{pkg_name}: {file_name}")
		with open(file_name, 'r', encoding='UTF8') as makefile:
			for line in makefile:
				if line.startswith(version_string):
					v = line.split('=')
					version_values[v[0].strip()] = v[1].strip()
		# probably virtual package
		if not version_values:
			return None, None
		v = version_values[version_string]
		while m := search(r'\$\(([A-Z_0-9]+)\)', v):
			replacement = version_values[m.group(1)]
			v = v.replace(m.group(0), replacement)
		return v, version_values

	@classmethod
	def create_session(cls):
		''' session handling '''
		cls._session = requests.Session()

	@classmethod
	def close_session(cls):
		''' session handling '''
		if cls._session:
			cls._session.close()

	def get_release_version(self):
		''' get current release version from release-monitoring.org '''
		n = 4
		while n > 0:
			try:
				self._session.get(self._release_monitoring_url,
					params={ 'name': self.package['project'] },
					timeout=TIMEOUT,
					hooks = {'response': self.process_release_monitoring_request})
				return
			# requests.exceptions.ConnectionError: ('Connection aborted.',
			# RemoteDisconnected('Remote end closed connection without response'))
			except ConnectionError as e:
				n -= 1

	def process_release_monitoring_request(self, response, **kwargs):
		'''
			Response function: retrieve latest software version from
			the project's data on release-monitoring.org.
		'''
		if kwargs:
			del kwargs	# W0613: unused-argument
		project = json.loads(response.text)
		latest_version = ''
		excluded_providers = _exclude_providers(self.package['name'])
		# there may be more than one provider (e.g. ca-certificates)
		for item in project['items']:
			if item['backend'] in  excluded_providers:
				continue
			v = item['version']
			if _version_value(v) > _version_value(latest_version):
				latest_version = v
		self.package['_rm_version'] = latest_version

	def version(self):
		''' Return both version strings from release-monitoring and github '''
		_br_version = self.package['_br_version'] if '_br_version' in self.package else ''
		_rm_version = self.package['_rm_version'] if '_rm_version' in self.package else ''
		return _br_version, _rm_version

	def update(self) -> bool:
		''' Uodate the package version in the Buildroot makefile '''
		_pattern = (
			r'(?P<major>[0-9]{1,2}){0,1}'
			r'(?P<minor>.[0-9]{1,2}){0,1}'
			r'(?P<patch>.[0-9]{1,2}){0,1}'
			r'(?P<point>[.p][0-9]{1,2}){0,1}'
			)
		version_values = self.package['_version_values']
		new_version = self.package['_rm_version']
		if DEBUG_LEVEL:
			print(version_values)
		i = 1
		for version_string, version_value in version_values.items():
			# replace simple version value
			if len(version_values) == 1:
				version_values[version_string] = new_version
			# consume from the start of the version value
			elif i < len(version_values):
				if m := match(_pattern, version_value):
					sz = 0
					for s in m.groups():
						if s:
							sz += len(s)
					version_values[version_string] = new_version[:sz]
					new_version = new_version[sz:]
					i += 1
				else:
					print(f"{self.package['name']}: cannot parse version string: {version_value}")
					print(f"  {version_values}")
					return False
			# use the remainder
			else:
				sz = len(new_version)
				version_values[version_string] = \
					version_values[version_string][:-sz] + new_version
			# finish when complete version string has been consumed
			if not version_value:
				break

		if DEBUG_LEVEL:
			print(version_values)
			return True

		# create tmp file
		new_file = self.package['path'] + '~'
		# process and copy lines from original file to tmp file
		with open(self.package['path'], 'r', encoding='UTF8') as src:
			with open(new_file, 'w', encoding='UTF8') as dst:
				for line in src:
					for version_string, version_value in version_values.items():
						if not version_value:
							continue
						if line.startswith(version_string):
							line = f"{version_string} = {version_value}\n"
							break
					dst.write(line)
		# remove original file and rename tmp file
		os.remove(self.package['path'])
		os.rename(new_file, self.package['path'])

		return True


# Source - https://stackoverflow.com/a/34325723
# Posted by Greenstick, modified by community. See post 'Timeline' for change history
# Retrieved 2026-09-27, License - CC BY-SA 4.0

# Print iterations progress
# pylint: disable=invalid-name,line-too-long,too-many-arguments,too-many-positional-arguments
def printProgressBar (iteration, total, prefix = '', suffix = '', decimals = 1, length = 100, fill = '█', printEnd = "\r"):
	'''
	Call in a loop to create terminal progress bar
	@params:
    	iteration   - Required  : current iteration (Int)
    	total       - Required  : total iterations (Int)
    	prefix      - Optional  : prefix string (Str)
    	suffix      - Optional  : suffix string (Str)
    	decimals    - Optional  : positive number of decimals in percent complete (Int)
    	length      - Optional  : character length of bar (Int)
    	fill        - Optional  : bar fill character (Str)
    	printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
	'''
	percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
	filledLength = int(length * iteration // total)
	progress_bar = fill * filledLength + '-' * (length - filledLength)
	print(f'\r{prefix} |{progress_bar}| {percent}% {suffix}', end = printEnd)
	# Print New Line on Complete
	if iteration == total:
		print()


def _is_python_package(name: str) -> bool:
	result = name in PYTHON_PACKAGES or name.startswith('python-')
	return result

def _exclude_providers(name: str) -> list:
	excluded_providers = EXCLUDE_PROVIDERS.copy()
	if not _is_python_package(name):
		excluded_providers.append('PyPI')
	if name == 'cmake':
		excluded_providers.remove('GitLab')
	return excluded_providers


def _version_value(version_string: str):
	'''
		analyse the version, determine the type (dotted, date, hash)
		and return a weighted value for the vrsion
	'''
	_patterns = {
		'dotted': (
			r'(?P<major>[0-9]{1,2})'
			r'(?P<minor>.[0-9]{1,2}){0,1}'
			r'(?P<patch>.[0-9]{1,2}){0,1}'
			r'(?P<point>.[0-9]{1,2}){0,1}'
			),
		'date': r'(?P<year>[0-9]{4})(?P<month>.[0-9]{2})(?P<day>.[0-9]{2})',
		'hash': r'[0-9][a-f]{7,12}',
		}

	for name, pattern in _patterns.items():
		m = match(pattern, version_string)
		if m:
			if name == 'dotted':
				i = 3
				total = 0
				for s in m.groups():
					if not s:
						break
					s = s[1:] if not s[0].isnumeric() else s
					total += float(s) * 100 ** (i-1)
					i -= 1
				return total
			if name == 'date':
				s = ''.join(version_string.split('-'))
				return float(s)
			if name == 'hash':
				return -1
	return -1


def read_package_names():
	''' Get a list of all packages which are actively in use'''
	print('Collect package names')
	# retrieve all downloaded packages
	p = os.path.join(os.path.expanduser(BUILDROOT_DIR), DOWNLOAD, '*')
	pkg_names = [ os.path.basename(d) for d in glob(p) if os.path.isdir(d) ]
	if DEBUG_LEVEL > 1:
		pkg_names = TEST_PKG_NAMES
	# filter names against buildroot packages
	pb = os.path.join(os.path.expanduser(BUILDROOT_DIR), PACKAGE)
	px = os.path.join(os.path.expanduser(EXTERNAL_DIR), PACKAGE)
	pkg_names = [ d for d in pkg_names if d not in FORCE_EXCLUSION and
		( os.path.isdir(os.path.join(px, d)) or os.path.isdir(os.path.join(pb, d)) ) ]
	return sorted(pkg_names)


def create_package_list(pkg_names):
	''' Retrieve package information from buildroot and the internet '''
	print('Retrieve package information')
	packages = {}
	iteration = 0
	total = len(pkg_names)
	BuildrootPackage.create_session()
	for n in pkg_names:
		if not DEBUG_LEVEL:
			printProgressBar(iteration, total, prefix=f"  {n:17.17} ", length=40)
		if p := BuildrootPackage.from_package(n):
			p.get_release_version()
			# some libraries have a stripped project name
			if not p.package['_rm_version'] and p.package['project'].startswith('lib'):
				p.package['project'] = p.package['project'][3:]
				p.get_release_version()
			packages[n] = p
		elif DEBUG_LEVEL:
			print(f"{n}: not defined as package")
		iteration += 1
	BuildrootPackage.close_session()
	return packages


def update_packages(pkg_list):
	''' Process outdated packages '''
	print('Process outdated packages')
	for n, p in pkg_list.items():
		vb, vr = p.version()
		if not vr:
			print(f"{n}: not found")
		elif _version_value(vb) < _version_value(vr):
			if p.update():
				print(f"{n}: updated from {vb} to {vr}")
			else:
				print(f"{n}: could not update")
		elif DEBUG_LEVEL:
			print(f"{n}: {vb} {vr}")

def hash_pattern(name: str) -> str:
	''' build the pattern used in the hash file '''
	return r'([\w]+)  [0-9a-f]{32,64}  ' + name + r'[-_][\w.-]+'

def read_hash_file(name: str) -> object:
	''' read all current hash values from the hash file '''
	if pkg := BuildrootPackage.from_package(name):
		hashfile = pkg.package['path'].replace('.mk', '.hash')
		_pattern = hash_pattern(pkg.package['source'])
		hash_entries = {}
		if os.path.isfile(hashfile):
			with open(hashfile, "r", encoding='utf8') as _file:
				for line in _file:
					if m := search(_pattern, line):
						hash_entries[m.group(1)] = m.group(0)
		else:
			print(f"{pkg.package['name']}: hash file does not exist")
			sys.exit(0)
		pkg.package['hash_entries'] = hash_entries
	return pkg

def update_hash_values(pkg: object):
	''' calculate new hash values for all entries '''
	p = os.path.join(os.path.expanduser(BUILDROOT_DIR),
		DOWNLOAD,
		pkg.package['name'],
		f"{pkg.package['source']}[_-]{pkg.package['_br_version']}[.-]*")
	archive_names = glob(p)
	if len(archive_names) > 0:
		for hash_provider in pkg.package['hash_entries']:
			cmd = [ hash_provider + 'sum', archive_names[0] ]
			rc = run(cmd, capture_output=True, check=False)
			hash_string = rc.stdout.decode()
			hash_value, file_path = hash_string.split()
			hash_string = f"{hash_provider}  {hash_value}  {file_path.split('/')[-1]}"
			pkg.package['hash_entries'][hash_provider] = hash_string
	else:
		print(f"{pkg.package['name']}: no archive with version {pkg.package['_br_version']}")
		sys.exit(1)
	return pkg

def update_hash_file(pkg: object):
	''' update the hash file with new values '''
	hashfile = pkg.package['path'].replace('.mk', '.hash')
	tmpfile = hashfile + '~'
	_pattern = hash_pattern(pkg.package['source'])
	lines_changed = 0
	with open(hashfile, "r", encoding='utf8') as src:
		with open(tmpfile, "w", encoding='utf8') as dst:
			for line in src:
				if m := search(_pattern, line):
					new_hash = pkg.package['hash_entries'][m.group(1)] + '\n'
					if line != new_hash:
						line = new_hash
						lines_changed += 1
				dst.write(line)
	# remove original file and rename tmp file
	if lines_changed:
		os.remove(hashfile)
		os.rename(tmpfile, hashfile)
		print(f"{pkg.package['name']}: hash values updated")
	else:
		os.remove(tmpfile)
		print(f"{pkg.package['name']}: hash values correct")

def _print_usage(argv: list):
	cmd = argv[0].split('/')[-1].split('.')[0]
	print(f"Usage: {cmd} --update to update active Buildroot package versions")
	print("  or           --hash <pkg> to update a packages hash value")
	print("               --debug (repeated N times) to activate debug level N")
	return 1


def vupdate(argv: list):
	''' Main function of the module '''

	global DEBUG_LEVEL
	while '--debug' in argv:
		DEBUG_LEVEL += 1
		argv.remove('--debug')
	if len(argv) == 2 and argv[1] == '--update':
		packages = read_package_names()
		packages = create_package_list(packages)
		update_packages(packages)

	elif len(argv) == 3 and argv[1] == '--hash':
		package = read_hash_file(argv[2])
		package = update_hash_values(package)
		update_hash_file(package)

	else:
		sys.exit(_print_usage(argv))


if __name__ == '__main__':
	sys.exit(vupdate(sys.argv))
