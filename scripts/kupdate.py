#!/bin/python

import io
import json
import os
import requests
import shutil
import sys
import tempfile

from bs4 import BeautifulSoup as soup
from shutil import copystat, move

config_file = '~/br2-external/Config.in.linux'


### Linux kernel versions as found on kernel.org
class KernelVersions:

	_kernel_url = 'https://www.kernel.org/releases.json'
	kernel_versions = None

	def __init__(self):
		response = requests.get(self._kernel_url,
			hooks = {'response': self.process_kernel_versions})

	# Retrieve the current kernel versions.
	# kernel.org provides a list in JSON format
	def process_kernel_versions(self, response, **kwargs):
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
		return self.kernel_versions[base_version]['version']

	def get_latest_version(self):
		v = next(iter(self.kernel_versions))
		return v, self.get_version(v)


### PREEMPT_RT patch versions from kernel.org
class KernelPatches:

	_patch_url = 'https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/'
	_patch_type = '.patch.xz'
	_kernel_versions = None
	patch_versions = None

	def __init__(self, kernel_versions):
		self._kernel_versions = kernel_versions
		response = requests.get(self._patch_url,
			hooks = {'response': self.process_patch_versions})

	def process_patch_versions(self, response, **kwargs):
		self.patch_versions = {}
		page = soup(response.text, 'html.parser')
		a = page.find_all('a')
		for t in a:
			vb = t.text[:-1]
			if vb in self._kernel_versions:
				# next page contains list of patches sorted by date
				# first lines contain directories, last line contains sha256sum.asc
				# correct file name ends with '.patch.xz'
				url = self._patch_url + t.text
				page = soup(requests.get(url).text, 'html.parser')
				_a = page.find_all('a')

				v = None
				for _t in _a:
					if _t.text.endswith(self._patch_type):
						v = _t.text

				self.patch_versions[vb] = {'patch': url + v}

	def __contains__(self, base_version):
		return base_version in self.patch_versions

	def get_patch(self, base_version):
		if base_version in self.patch_versions:
			return self.patch_versions[base_version]['patch']
		return ''

	def get_kernel_version(self, base_version):
		_v = base_version.split('-')[1:-1]
		lv = _v[0] + '-' + _v[1] if len(_v) == 2 else _v[0]
		return lv


def get_release_monitoring_version(project='mpd'):
	url = "https://release-monitoring.org/api/v2/projects/?name=%s" % project
	response = requests.get(url)
	projects = json.loads(response.text)
	v = projects['items'][0]['version']
	return v

def get_github_version(owner='MusicPlayerDaemon', repo='MPD'):
	url = 'https://api.github.com/repos/%s/%s/tags' % (owner, repo)
	response = requests.get(url)
	tags = json.loads(response.text)
	v = tags[0]['name'][1:]
	return v


# Config syntax is:
"""
if <symbol>
config <symbol>
\tstring
\tdefault <value>
endif '#' <symbol>
"""

#strings for parsing
CUSTOM_VERSION = 'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM'
LATEST_VERSION = 'BR2_TOOLCHAIN_HEADERS_LATEST'

# states for parsing
config_symbol = None
header_version = None
LINUX_VERSION = 1
LINUX_PATCH = 2
config_block = None
changes_made = 0
line_number = 0

def terminal_error(line_number, message):
	e = 'line %d: %s' % (line_number, message)
	raise RuntimeError(e)

def get_version(key, value):
	for k, v in linux_versions.items():
		if v[key] == value:
			return v
	return None

def reconstruct_line(array):
	result = '\t'
	for i in range(len(array)):
		result = result + array[i] + ' '
	result = result[:-1] + '\n'
	return result

def parse(line, kernel_version, kernel_patch):
	global config_symbol
	global header_version
	global config_block
	global changes_made
	global line_number

	line_number += 1

	# begin of version block
	if line.startswith('if'):
		if not header_version:
			t = line.strip().split(' ')
			config_symbol = t[1]
			if config_symbol == LATEST_VERSION:
				header_version = kernel_version.get_latest_version()[0]
			if config_symbol.startswith(CUSTOM_VERSION):
				header_version = '%s.%s' % tuple(config_symbol.split('_')[-2:])
			if not header_version:
				terminal_error(line_number, 'Unknown symbol %s' % t[1])
		else:
			terminal_error(line_number, 'Unterminated block %s' % config_symbol)

	# config item
	elif line.startswith('config'):
		if header_version:
			t = line.strip().split(' ')
			if t[-1] == 'NABLA_LINUX_VERSION':
				config_block = LINUX_VERSION
			elif t[-1] == 'NABLA_LINUX_PATCH':
				config_block = LINUX_PATCH
		else:
			terminal_error(line_number, 'Configuration item outside of version block')

	# config value(s)
	elif line.startswith('\t'):
		t = line.strip().split(' ')
		if t[0] == 'default':

			if config_block == LINUX_VERSION:
				v = '"' + kernel_version.get_version(header_version) + '"'
				if t[1] != v:
					print("%s: replacing %s with %s" % (config_symbol, t[1], v))
					t[1] = v
					line = reconstruct_line(t)
					changes_made += 1

			elif config_block == LINUX_PATCH:
				p = '"' + kernel_patch.get_patch(header_version) + '"'
				if t[1] != p:
					print("%s: replace %s with %s" % (config_symbol, t[1], p))
					t[1] = p
					line = reconstruct_line(t)
					changes_made += 1

			else:
				terminal_error(line_number, 'Config value outside of config block')

	# end of version block
	elif line.startswith('endif'):
		if header_version:
			t = line.strip().split(' ')
			if t[-1] != config_symbol:
				terminal_error(line_number, 'Symbol %s not matching %s' % (t[-1], config_symbol))
			config_symbol = None 
			header_version = None 
		else:
			terminal_error(line_number, 'Unmatched endif %s' % t[-1])

	return line


def kupdate(argv):

	# convert argument(s) to single string containing letters only
	options = ''.join([ s[1:] for s in argv[1:] ])
	# use kernel versions matching kernel patches
	matching_versions = True if 'm' in options else False
	# just print what would be changed, do not modify the config file
	trial_run = True if 'n' in options else False
	# retrieve and print the mpd version from release-monitoring and github
	mpd_version = True if 'p' in options else False

	v = KernelVersions()
	p = KernelPatches(v)

	filename = os.path.expanduser(config_file)
	dirname = os.path.dirname(filename)

	# Parse and modify the original file line-by-line into a temporary file
	with tempfile.NamedTemporaryFile(mode='w', dir=dirname, delete=False) as tmp_file:
		with open(filename) as src_file:
			for line in src_file:
				line = parse(line, v, p)
				tmp_file.write(line)

	if mpd_version:
		print("mpd version:  release-monitoring = %s  github = %s" %(
			get_release_monitoring_version(),
			get_github_version()
			))

	# Overwrite the original file with the modified temporary file in a
	# manner preserving file attributes (e.g., permissions).
	if changes_made and not trial_run:
		shutil.copystat(filename, tmp_file.name)
		shutil.move(tmp_file.name, filename)
	else:
		os.remove(tmp_file.name)

if __name__ == '__main__':
	sys.exit(kupdate(sys.argv))
