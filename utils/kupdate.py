#!/bin/python

'''
	kupdate: update Buildroot configuration with latest kernel and PREEMPT_RT
	versions
'''

import json
import os
from re import search
import shutil
from time import mktime, strptime
import sys
import tempfile

import requests
from bs4 import BeautifulSoup as soup

CONFIG_FILE = 'Config.in.linux'
TIMEOUT = 30


class KernelVersions:
	''' Supported Linux kernel versions as found on kernel.org '''

	_kernel_url = 'https://www.kernel.org/releases.json'
	kernel_versions = None

	def __init__(self):
		requests.request('GET',
			self._kernel_url,
			timeout = TIMEOUT,
			hooks = {'response': self.process_kernel_versions})

	def process_kernel_versions(self, response, **kwargs):
		''' Response function: retrieve the current kernel versions.
			kernel.org provides a list in JSON format '''
		if kwargs:
			del kwargs	# W0613: unused-argument
		self.kernel_versions = {}
		db = json.loads(response.text)
		for r in db['releases']:
			v = r['version']
			vb = self._base_version(v)
			t = r['released']['timestamp']
			self.kernel_versions[vb] = {
				'version': v, 
				'timestamp': t,
				}

	def __contains__(self, version):
		return version in self.kernel_versions

	@staticmethod
	def _base_version(v):
		_v = v.strip('"')
		_v = _v.split('-')[0] # get rid of the release candidate
		_v = _v.split('.')
		vb = _v[0] + '.' + _v[1] if len(_v) > 1 else _v[0]
		return vb

	def get_version(self, base_version):
		''' get the latest patch version (x.y.z) for a kernel tree (x.y) '''
		return self.kernel_versions[base_version]['version']

	def get_latest_version(self):
		''' get the current mainline kernel version '''
		v = next(iter(self.kernel_versions))
		return v, self.get_version(v)


class KernelPatches(KernelVersions):
	''' PREEMPT_RT patches matching currently supported kernel versions '''

	_patch_url = 'https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/'
	_pattern = r'patch-[0-9crt.-]+\.patch.xz'
	_time_format = '%d-%b-%Y %H:%M'
	patch_versions = None

	def __init__(self):
		super().__init__()
		requests.request('GET',
			self._patch_url,
			timeout = TIMEOUT,
			hooks = {'response': self.process_patch_versions})

	def process_patch_versions(self, response, **kwargs):
		''' 
			response function: retrieves the current patch version
			for all supported Linux base versions
		'''
		if kwargs:
			del kwargs	# W0613: unused-argument
		self.patch_versions = {}
		page = soup(response.text, 'html.parser')
		a = page.find_all('a')
		for t in a:
			vb = t.text[:-1]
			if vb in self.kernel_versions:
				# next page contains list of patches sorted by date
				# first lines contain directories, last line contains sha256sum.asc
				# correct file name ends with '.patch.xz'
				url = self._patch_url + t.text
				page = soup(requests.request('GET', url, timeout=TIMEOUT).text, 'html.parser')

				t = None
				v = None
				# the preformatted text element contains rows of releases
				for s in page.body.pre.get_text().split('\r\n'):
					if search(self._pattern, s):
						p = s.split()
						t = mktime(strptime(' '.join(p[1:3]), self._time_format))
						v = p[0]
						break	# use the first entry, list is sorted by date

				# matching kernel version
				mv = v.split('-')
				mv = mv[1:-1]
				mv = '-'.join(list(mv))

				self.patch_versions[vb] = {
					'patch': url + v,
					'matching_version': mv,
					'timestamp': t,
					}

	def __contains__(self, base_version):
		return base_version in self.patch_versions

	def get_patch(self, base_version):
		''' returns the URL of the patch for a Linux base version '''
		if base_version in self.patch_versions:
			return self.patch_versions[base_version]['patch']
		return ''

	def get_basename(self, patch_url):
		''' strips a patch URL to retrieve the patch file name '''
		return patch_url.strip('"').split('/')[-1]

	def get_patch_level(self, basename):
		''' strips a patch file name to retrieve the patch version number '''
		if basename:
			r = basename.rstrip(self._pattern[-9:]).split('-')
			pat = [ r'rt[0-9]+', r'rc[0-9]+', ]
			# isolate patch version rt[0-9]-rc[0-9]
			r = r[[i for i, v in enumerate(r) if search(pat[0], v)][-1]:]
			# maximum patch number = 999
			l = int(r[0].lstrip(pat[0][:2])) * 1000
			l += int(r[1].lstrip(pat[1][:2])) if len(r) > 1 else 0
			return l
		return 0

	def get_version(self, base_version, matching=False):
		''' overload kernel version: return the latest version (x.y.z)
			for a kernel tree (x.y) that is supported by a current
			RT_PREEMPT patch '''
		if matching and base_version in self.patch_versions:
			return self.patch_versions[base_version]['matching_version']
		return super().get_version(base_version)


class CIPKernelVersion:
	''' Supported CIP kernel versions as found on kernel.org '''

	_kernel_branch = '5.10'
	_kernel_url = \
		f"https://www.kernel.org/pub/linux/kernel/projects/cip/{_kernel_branch}/"
	_pattern = r'linux-cip-\d+.\d{1,2}.\d{1,3}-cip\d+-rt\d+.tar.xz'
	kernel_version = ''

	def __init__(self):
		requests.request('GET',
			self._kernel_url,
			timeout = TIMEOUT,
			hooks = {'response': self.process_kernel_versions})

	def process_kernel_versions(self, response, **kwargs):
		''' Response function: retrieve the latest version
			from the given result page. '''
		if kwargs:
			del kwargs	# W0613: unused-argument
		kernel_versions = {}
		page = soup(response.text, 'html.parser')
		a = page.find_all('a')
		for t in a:
			r = t.text
			if search(self._pattern, r):
				p = r.split('-')
				v = int(p[-2].replace('cip', ''))
				p[-1] = p[-1].replace(self._pattern[-7:], '')
				kernel_versions[v] = '-'.join(p[2:])
		v = sorted(kernel_versions.keys())[-1]
		self.kernel_version = f'"{kernel_versions[v]}"'

	def get_latest_version(self):
		''' get the latest CIP RT version for the configured kernel tree '''
		return self._kernel_branch, self.kernel_version


class PackageVersion:
	''' package versions, retrived from release-monitoring.org and github tags '''

	_github_url = 'https://api.github.com/repos/%s/%s/tags'
	_release_monitoring_url = "https://release-monitoring.org/api/v2/projects/?name=%s"
	_git_version = None
	_rm_version = None

	def __init__(self, owner, project):
		url = self._release_monitoring_url % project
		requests.request('GET',
			url,
			timeout=TIMEOUT,
			hooks = {'response': self.process_release_monitoring_request})
		url = self._github_url % (owner, project)
		requests.request('GET',
			url,
			timeout=TIMEOUT,
			hooks = {'response': self.process_github_request})

	def process_release_monitoring_request(self, response, **kwargs):
		''' 
			Response function: retrieve latest software version from
			the project's data on release-monitoring.org.
		'''
		if kwargs:
			del kwargs	# W0613: unused-argument
		projects = json.loads(response.text)
		self._rm_version = projects['items'][0]['version']

	def process_github_request(self, response, **kwargs):
		''' 
			Response function: retrieve the latest tag version from
			the projects github repository.
		'''
		if kwargs:
			del kwargs	# W0613: unused-argument
		tags = json.loads(response.text)
		self._git_version = tags[0]['name'][1:]

	def get_version(self):
		''' Return both version strings from release-monitoring and github '''
		return self._rm_version, self._git_version


# Config syntax is:
#	if <symbol>
#	config <symbol>
#	\tstring
#	\tdefault <value>
#	endif # <symbol>

# strings for parsing
CUSTOM_VERSION = 'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM'
LATEST_VERSION = 'BR2_TOOLCHAIN_HEADERS_LATEST'
LATEST_CIP_VERSION = 'BR2_LINUX_KERNEL_LATEST_CIP_RT_VERSION'
# flags for parsing
LINUX_VERSION = 1
LINUX_PATCH = 2

class LineParser:
	''' Stateful line parser for the Config.linux.in file '''

	### parsing states
	_config_symbol = None
	_header_version = None
	_config_block = None

	def __init__(self, matching, mtime):
		self.changes_made = 0
		self.line_number = 0
		self.matching = matching
		self.mtime = mtime
		self.versions = KernelPatches()
		self.cip_version = CIPKernelVersion()

	def terminal_error(self, message):
		''' Terminate the program with an error message '''
		e = f'line {self.line_number}: {message}'
		raise RuntimeError(e)

	### block parsing functions

	def _version_block_start(self, line):
		''' start of version block '''
		if not self._header_version:
			t = line.strip().split(' ')
			self._config_symbol = t[1]
			if self._config_symbol == LATEST_VERSION:
				self._header_version = \
					self.versions.get_latest_version()[0]
			elif self._config_symbol == LATEST_CIP_VERSION:
				self._header_version = \
					self.cip_version.get_latest_version()[0]
			elif self._config_symbol.startswith(CUSTOM_VERSION):
				self._header_version = \
					'.'.join(self._config_symbol.split('_')[-2:])
			if not self._header_version:
				self.terminal_error(f'Unknown symbol {t[1]}')
		else:
			self.terminal_error(f'Unterminated block {self._config_symbol}')

	def _config_item(self, line):
		''' config item '''
		if self._header_version:
			t = line.strip().split(' ')
			if t[-1] == 'NABLA_LINUX_VERSION':
				self._config_block = LINUX_VERSION
			elif t[-1] == 'NABLA_LINUX_PATCH':
				self._config_block = LINUX_PATCH
		else:
			self.terminal_error('Configuration item outside of version block')

	def _config_value(self, line):
		''' config value(s) '''
		t = line.strip().split(' ')
		if t[0] == 'default':

			if	self._config_block == LINUX_VERSION and \
				self._config_symbol == LATEST_CIP_VERSION:
				v = self.cip_version.get_latest_version()[1]
				if v != t[1]:
					print(f"{self._config_symbol}: replace {t[1]} with {v}")
					t[1] = v
					line = '\t' + ' '.join(list(t)) + '\n'
					self.changes_made += 1

			elif self._config_block == LINUX_VERSION:
				kv = self.versions.get_version(self._header_version, matching=self.matching)
				v = '"' + kv + '"'
				if v != t[1]:
					print(f"{self._config_symbol}: replace {t[1]} with {v}")
					t[1] = v
					line = '\t' + ' '.join(list(t)) + '\n'
					self.changes_made += 1

			# The new rt patch version must be greater than the
			# last version, otherwise it will not be replaced
			elif self._config_block == LINUX_PATCH:
				pv = self.versions.get_patch(self._header_version)
				p = '"' + pv + '"'
				cur = self.versions.get_basename(t[1])
				new = self.versions.get_basename(p)
				if (not new and cur) or \
					self.versions.get_patch_level(new) > self.versions.get_patch_level(cur):
					print(f'{self._config_symbol}: replace "{cur}" with "{new}"')
					t[1] = p
					line = '\t' + ' '.join(list(t)) + '\n'
					self.changes_made += 1
				elif (new and not cur) or \
					self.versions.get_patch_level(new) < self.versions.get_patch_level(cur):
					print(f"{self._config_symbol}: {cur} is newer")

			else:
				self.terminal_error('Config value outside of config block')
		return line

	def _version_block_finish(self, line):
		''' end of version block '''
		if self._header_version:
			t = line.strip().split(' ')
			if t[-1] != self._config_symbol:
				self.terminal_error(f'Symbol {t[-1]} not matching {self._config_symbol}')
			self._config_symbol = None
			self._header_version = None
		else:
			self.terminal_error(f'Unmatched endif {t[-1]}')

	### main parser

	def parse(self, line):
		''' Parse one line into symbols, replace changed versions,
			return the modified line '''

		self.line_number += 1

		if line.startswith('if'):
			self._version_block_start(line)

		elif line.startswith('config'):
			self._config_item(line)

		elif line.startswith('\t'):
			line = self._config_value(line)

		# end of version block
		elif line.startswith('endif'):
			self._version_block_finish(line)

		return line


def kupdate(argv):
	''' Main function of the module '''

	# convert argument(s) to single string containing letters only
	options = ''.join([ s[1:] for s in argv[1:] ])
	# use kernel versions matching kernel patches
	matching_versions = 'm' in options
	# just print what would be changed, do not modify the config file
	trial_run = 'n' in options
	# retrieve and print the mpd version from release-monitoring and github
	mpd_version = 'p' in options

	dirname = os.path.dirname(os.path.realpath(argv[0]))
	filename = os.path.join(dirname, CONFIG_FILE)
	homedir = os.path.dirname(os.path.realpath('~'))
	while not os.path.samefile(dirname, homedir) and not os.path.exists(filename):
		dirname = os.path.dirname(dirname)
		filename = os.path.join(dirname, CONFIG_FILE)

	mtime = os.stat(filename).st_mtime
	parser = LineParser(matching_versions, mtime)

	# Parse and modify the original file line-by-line into a temporary file
	with tempfile.NamedTemporaryFile(mode='w', dir=dirname, delete=False) as tmp_file:
		with open(filename, encoding='UTF8') as src_file:
			for line in src_file:
				line = parser.parse(line)
				tmp_file.write(line)

	if mpd_version:
		mpd = PackageVersion('MusicPlayerDaemon', 'mpd')
		v1, v2 = mpd.get_version()
		print(f"{'mpd version':>32}")
		print(f"{'Release monitoring':>20} {v1:>11}")
		print(f"{'Github':>20} {v2:>11}")

	# Overwrite the original file with the modified temporary file in a
	# manner preserving file attributes (e.g., permissions).
	if parser.changes_made and not trial_run:
		shutil.copystat(filename, tmp_file.name)
		shutil.move(tmp_file.name, filename)
	else:
		os.remove(tmp_file.name)

if __name__ == '__main__':
	sys.exit(kupdate(sys.argv))
