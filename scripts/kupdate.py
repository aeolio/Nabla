#!/bin/python

import io
import json
import os
import requests
import shutil
import tempfile

from bs4 import BeautifulSoup as soup
from shutil import copystat, move

# config_file = '~/br2_external/Config.in.linux'
config_file = '/tmp/Config.in.linux'
kernel_url = 'https://www.kernel.org/releases.json'
patch_url = 'https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/'
patch_type = '.patch.xz'

linux_versions = { 
	# stable version for 32-bit hardware
	'5.10': { 'symbol': 'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_5_10' },
 	# stable version for 64-bit hardware
	'6.6': { 'symbol': 'BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6' },
	# experimental
	'6.10': { 'symbol': 'BR2_KERNEL_HEADERS_LATEST' },
	}

# kernel.org provides a list in JSON format
response = requests.get(kernel_url)
db = json.loads(response.text)
for r in db['releases']:
	v = r['version']
	_v = v.split('-')[0] # get rid of the release candidate
	_v = _v.split('.')
	vb = _v[0] + '.' + _v[1] if len(_v) > 1 else _v[0]
	if vb in linux_versions:
		linux_versions[vb]['version'] = v

# PREEMPT_RT patch
response = requests.get(patch_url)
page = soup(response.text, 'html.parser')
a = page.find_all('a')

for t in a:
	vb = t.text[:-1]
	if vb in linux_versions:
		# next page contains list of patches sorted by date
		# first lines contain directories, last line contains sha256sum.asc
		# correct file name ends with '.patch.xz'
		url = patch_url + t.text
		page = soup(requests.get(url).text, 'html.parser')
		_a = page.find_all('a')

		v = None
		for _t in _a:
			if _t.text.endswith(patch_type):
				v = _t.text

		linux_versions[vb]['patch'] = url + v

# Config syntax is:
"""
if <symbol>
config <symbol>
\tstring
\tdefault <value>
endif '#' <symbol>
"""

# states for parsing
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

def parse(line):
	global header_version
	global config_block
	global changes_made
	global line_number

	line_number += 1

	# begin of version block
	if line.startswith('if'):
		if not header_version:
			t = line.strip().split(' ')
			header_version = get_version('symbol', t[1])
			if not header_version:
				terminal_error(line_number, 'Unknown symbol %s' % t[1])
		else:
			terminal_error(line_number, 'Unterminated block %s' % header_version['symbol'])

	# config item
	elif line.startswith('config'):
		if header_version:
			t = line.strip().split(' ')
			if t[-1] == 'NABLA_LINUX_VERSION':
				config_block = LINUX_VERSION
			elif t[-1] == 'NABLA_LINUX_PATCH':
				config_block = LINUX_PATCH
		else:
			terminal_error(line_number, 'Configuration %s outside of version block' % t[2])

	# config value(s)
	elif line.startswith('\t'):
		t = line.strip().split(' ')
		if t[0] == 'default':

			if config_block == LINUX_VERSION:
				v = '"' + header_version['version'] + '"'
				if t[1] != v:
					print("%s: replacing %s with %s" % (header_version['symbol'], t[1], v))
					t[1] = v
					line = reconstruct_line(t)
					changes_made += 1

			elif config_block == LINUX_PATCH:
				p = '"' + header_version['patch'] + '"'
				if t[1] != p:
					print("%s: replace %s with %s" % (header_version['symbol'], t[1], p))
					t[1] = p
					line = reconstruct_line(t)
					changes_made += 1

			else:
				terminal_error(line_number, 'Config value outside config block')

	# end of version block
	elif line.startswith('endif'):
		if header_version:
			t = line.strip().split(' ')
			if header_version['symbol'] != t[-1]:
				terminal_error(line_number, 'Symbol %s not matching %s' % (t[-1], header_version['symbol']))
			header_version = None 
		else:
			terminal_error(line_number, 'Unmatched endif %s' % t[-1])

	return line

filename = os.path.expanduser(config_file)
dirname = os.path.dirname(filename)

# Parse and modify the original file line-by-line into a temporary file
with tempfile.NamedTemporaryFile(mode='w', dir=dirname, delete=False) as tmp_file:
	with open(filename) as src_file:
		for line in src_file:
			line = parse(line)
			tmp_file.write(line)

# Overwrite the original file with the modified temporary file in a
# manner preserving file attributes (e.g., permissions).
if changes_made:
	shutil.copystat(filename, tmp_file.name)
	shutil.move(tmp_file.name, filename)
else:
	os.remove(tmp_file.name)

