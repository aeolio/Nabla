#!/bin/python

'''
	kupdate: update Buildroot configuration with latest kernel and PREEMPT_RT
	versions
'''

import json
import os
import shutil
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
			_v = v.split('-')[0] # get rid of the release candidate
			_v = _v.split('.')
			vb = _v[0] + '.' + _v[1] if len(_v) > 1 else _v[0]
			self.kernel_versions[vb] = {'version': v}

	def __contains__(self, version):
		return version in self.kernel_versions

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
	_patch_type = '.patch.xz'
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
				_a = page.find_all('a')

				v = None
				for _t in _a:
					if _t.text.endswith(self._patch_type):
						v = _t.text

				# matching kernel version
				mv = v.split('-')
				mv = mv[1:-1]
				mv = '-'.join(list(mv))

				self.patch_versions[vb] = {
					'patch': url + v,
					'matching_version': mv,
					}

	def __contains__(self, base_version):
		return base_version in self.patch_versions

	def get_patch(self, base_version):
		''' returns the URL of the patch for a Linux base version '''
		if base_version in self.patch_versions:
			return self.patch_versions[base_version]['patch']
		return ''

	def get_version(self, base_version, matching=False):
		''' overload kernel version: return the latest version (x.y.z)
			for a kernel tree (x.y) that is supported by a current
			RT_PREEMPT patch '''
		if matching and base_version in self.patch_versions:
			return self.patch_versions[base_version]['matching_version']
		return super().get_version(base_version)


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
# flags for parsing
LINUX_VERSION = 1
LINUX_PATCH = 2

class LineParser:
	''' Stateful line parser for the Config.linux.in file '''

	# states for parsing
	_config_symbol = None
	_header_version = None
	_config_block = None

	def __init__(self, matching):
		self.changes_made = 0
		self.line_number = 0
		self.matching = matching
		self.versions = KernelPatches()

	def terminal_error(self, message):
		''' Terminate the program with an error message '''
		e = f'line {self.line_number}: {message}'
		raise RuntimeError(e)

	def _version_block_start(self, line):
		''' start of version block '''
		if not self._header_version:
			t = line.strip().split(' ')
			self._config_symbol = t[1]
			if self._config_symbol == LATEST_VERSION:
				self._header_version = \
					self.versions.get_latest_version()[0]
			if self._config_symbol.startswith(CUSTOM_VERSION):
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

			if self._config_block == LINUX_VERSION:
				kv = self.versions.get_version(self._header_version, matching=self.matching)
				v = '"' + kv + '"'
				if t[1] != v:
					print(f"{self._config_symbol}: replace {t[1]} with {v}")
					t[1] = v
					line = '\t' + ' '.join(list(t)) + '\n'
					self.changes_made += 1

			elif self._config_block == LINUX_PATCH:
				pv = self.versions.get_patch(self._header_version)
				p = '"' + pv + '"'
				if t[1] != p:
					print(f"{self._config_symbol}: replace {t[1]} with {p}")
					t[1] = p
					line = '\t' + ' '.join(list(t)) + '\n'
					self.changes_made += 1

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

	dirname = os.path.dirname(argv[0])
	filename = os.path.join(dirname, CONFIG_FILE)
	while not os.path.ismount(dirname) and not os.path.exists(filename):
		dirname = os.path.dirname(dirname)
		filename = os.path.join(dirname, CONFIG_FILE)

	parser = LineParser(matching_versions)

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
