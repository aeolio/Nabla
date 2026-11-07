#!/bin/python

'''
	Generate a mpd.conf configuration file, based on defaults and
	configurations found in Buildroot and Linux .config files.
	Configuration files will be passed as (optional) program parameters,
	the last parameter in the list will be used to store the generated
	configuration file.
'''

import sys

from dataclasses import dataclass

HEADER = \
	'# MPD configuration file ({0})\n' \
	'# Version 3.1\n' \
	'# Example file: doc/mpdconf.example in the build directory\n' \
	'# Documentation: http://mpd.readthedocs.io/latest/user.html\n'

GENERAL_OPTIONS = \
	'\n### General music daemon options\n' \
	'user				"mpd"\n' \
	'auto_update			"yes"\n' \
	'auto_update_depth	"3"\n'

SYMBOLIC_LINK = \
	'\n### Symbolic link behavior\n' \
	'follow_outside_symlinks	"no"\n'

RESOURCE_LIMITATIONS = \
	'\n### Resource limitations\n' \
	'max_output_buffer_size	"{0}"\n'

INPUT_CACHE = \
	'\n### Internal buffer\n' \
	'input_cache {{\n' \
	'\tsize	"{0} MB"\n' \
	'}}\n'

REALTIME_OPTION = \
	'\n### Jan\'s real time patch\n' \
	'realtime_option {\n' \
	'\tmemlock				"yes"\n' \
	'\tstack_reserve		"1024"\n' \
	'\theap_reserve		"0"\n' \
	'\n' \
	'\tio_priority			"OTHER:0"\n' \
	'\trtio_priority		"FIFO:2"\n' \
	'\tmain_priority		"OTHER:0"\n' \
	'\tplayer_priority		"FIFO:1"\n' \
	'\tdecoder_priority	"FIFO:2"\n' \
	'\tupdate_priority		"OTHER:0"\n' \
	'}\n'

DATABASE_DIR = '/var/lib'
LOGFILE_DIR = '/var/log'
MOUNT_DIR = '/media'
RUNTIME_DIR = '/var/run'

DEBUG_OUTPUT = True

@dataclass
class ProgramOptions(dict):
	''' Holds the parameters parsed from Buildroot and Linux .config '''

	def __init__(self, *arg, **kw):
		super(ProgramOptions, self).__init__(*arg, **kw)

	def parse(self, text: str):
		''' extract information from kconfig file (buildroot, linux) '''

		if not text or text[0] == '#':
			return

		try:
			symbol, value = text.split('=')
			symbol = symbol.strip()
			value = value.lstrip().strip('\"')
			if value == 'y':
				value = True
			### from buildroot config
			if symbol.startswith('NABLA'):
				symbol = '_'.join(symbol.split('_')[1:])
				self[symbol.lower()] = value
			elif symbol.startswith('BR2_PACKAGE_MPD'):
				symbol = '_'.join(symbol.split('_')[3:])
				if symbol:
					self[symbol.lower()] = value

		# line with second assignment in value part
		except ValueError:
			if DEBUG_OUTPUT:
				print(text)

	def post_process(self):
		# there is no way to determine ram size at build time
		self['cache_size'] = 512
		self['output_buffer_size'] = 131072
		if 'client' in self:
			self['machine_type'] = 'client'
		elif 'server' in self:
			self['machine_type'] = 'server'
		if 'standalone' in self:
			self['machine_type'] = 'standalone'


def header(p: ProgramOptions, f: file):
	''' generate config file header '''
	f.write(HEADER.format(p['machine_type']))

def files_and_directories(p: ProgramOptions, f: file):
	''' Files and directories block '''
	print(f'\n### Files and directories', file=f)
	print(f'music_directory		"{MOUNT_DIR}"', file=f)
	if 'server' not in p:
		print(f'playlist_directory	"{DATABASE_DIR}/mpd/playlists"', file=f)
	print(f'state_file			"{DATABASE_DIR}/mpd/state"', file=f)
	print(f'pid_file			"{RUNTIME_DIR}/mpd/pid"', file=f)
	print(f'log_file			"{LOGFILE_DIR}/mpd/mpd.log"', file=f)

def resource_limitations(p: ProgramOptions, f: file):
	''' increase output buffer size '''
	if p['machine_type'] == 'server':
		f.write(RESOURCE_LIMITATIONS.format(p['output_buffer_size']))

def database(p: ProgramOptions, f: file):
	''' Database configuration '''
	print('\n### Database', file=f)
	print('database {', file=f)
	if 'libnfs' in p or 'libsmbclient' in p:
		print('\tplugin			"proxy"', file=f)
		print('\thost			"hostname', file=f)
		print('\tport	"6600"', file=f)
	else:
		print('\tplugin			"simple"', file=f)
		print(f'\tpath			"{DATABASE_DIR}/mpd/db"', file=f)
		print(f'\tcache_directory	"{DATABASE_DIR}/mpd/cache"', file=f)
		print('}', file=f)

def audio_output(p: ProgramOptions, f: file):
	''' audio output configuration '''
	print('\n### Audio Output', file=f)
	print('audio_output {', file=f)
	if 'alsa' in p:
		print('\ttype		"alsa"', file=f)
		print('\tname		"USB0"', file=f)
		print('\tdevice		"hw:0,0"', file=f)
		print('\tperiod_time		"10000"', file=f)
		print('\tbuffer_time		"100000"', file=f)
		print('\tmixer_type		"none"', file=f)
		print('\tauto_channels	"no"', file=f)
		print('\tauto_format		"no"', file=f)
		print('\tauto_resample	"no"', file=f)
		print('\tdop			"yes"', file=f)
		print('\tpriority	"FIFO:1"', file=f)
	else:
		print('\ttype		"null"', file=f)
		print('\tname		"mpd server"', file=f)
	print('}', file=f)

def input_cache(p: ProgramOptions, f: file):
	''' define input_cache size '''
	if p['machine_type'] != 'server':
		f.write(INPUT_CACHE.format(p['cache_size']))

def realtime_option(p: ProgramOptions, f: file):
	''' realtime option block '''
	if 'rt_option' in p:
		f.write(REALTIME_OPTION)


def write_config(p: ProgramOptions, config_file: str):
	''' generate a mpd.conf file '''

	if DEBUG_OUTPUT:
		for sym, val in p.items():
			print(f"{sym:>20} {val}")

	with open(config_file, mode="w", encoding='UTF8') as f:
		header(p, f)
		files_and_directories(p, f)
		f.write(GENERAL_OPTIONS)
		f.write(SYMBOLIC_LINK)
		resource_limitations(p, f)
		database(p, f)
		audio_output(p, f)
		input_cache(p, f)
		realtime_option(p, f)
		f.truncate()

def mpd_conf(config_files, target_file):
	''' Main function of the module '''
	p = ProgramOptions()
	for c in config_files:
		with open(c, encoding='UTF8') as config_file:
			for line in config_file:
				p.parse(line.strip())
	p.post_process()
	write_config(p, target_file)
	return 0

if __name__ == '__main__':
	# last parameter is the output file
	target = sys.argv[-1]
	# Linux and Buildroot config files
	configs = sys.argv[1:-1]
	sys.exit(mpd_conf(configs, target))
