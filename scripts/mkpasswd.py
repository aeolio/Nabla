#!/bin/python

'''
	Create an initial password for the root account. 
	Password creation is skipped, if the Buildroot 
	configuration contains a non-empty entry for the 
	root password (BR2_TARGET_GENERIC_ROOT_PASSWD)
'''

from collections.abc import Callable
from datetime import datetime
from hashlib import sha256
import os
from random import randint
from socket import gethostname
from subprocess import run
import sys

CONFIG_PASSWD = 'BR2_TARGET_GENERIC_ROOT_PASSWD'
CONFIG_METHOD = 'BR2_TARGET_GENERIC_PASSWD_METHOD'
PASSWORD_LENGTH = 6

def modify_shadow_file(shadow: str, user: str, paswd: str):
	pass

def encrypt_password(mkpasswd: str, method: str, passwd: str) -> str:
	# mkpasswd -m <method> passwd
	cmd = [
		mkpasswd,
		'-m',
		method,
		passwd,
		]
	rc = run(cmd, capture_output=True, check=True)
	output = rc.stdout.decode('utf-8').strip()
	if rc.returncode:
		raise ChildProcessError(output)
	return output

def generate_password(length: int):
	# corresponds to date -Ins
	_iso8601_fmt = '%Y-%m-%dT%H:%M:%S,%f%:z'
	iso8601_datetime = datetime.now().astimezone().strftime(_iso8601_fmt)
	s = gethostname() + iso8601_datetime
	digest = sha256(s.encode('utf-8')).hexdigest()
	n = len(digest) - length
	i = randint(0, n)
	return digest[i:i+length]

def read_config_value(config_file: str, variable: str) -> str:
	value = ''
	with open(config_file, 'r', encoding='utf-8') as config:
		for line in config:
			if line.startswith(variable):
				s = line.split('=')
				if s[0].strip() == variable:
					value = s[1].strip('\t\n "*')
					break
	return value

def _config_parser(line: str, items: list, generate=False) -> str:
	new_line = f"{items[0]}=\"{items[1]}\"\n"
	if generate:
		return True, new_line
	if line.startswith(items[0]):
		s = line.split('=')
		if s[0].strip() == items[0]:
			return True, new_line
	return False, line

def _shadow_parser(line: str, items: list, generate=False) -> str:
	if generate:
		return True, f"{items[0]}:{items[1]}:::::::\n"
	if line.startswith(items[0]):
		s = line.split(':')
		if s[0].strip() == items[0]:
			for i, item in enumerate(items[1:]):
				s[1+i] = item
			return True, ':'.join(s)
	return False, line

def write_entry(input_file: str, line_parser: Callable[[str, list, ...], str], items: list):
	temp_file = input_file + '.tmp'
	with open(temp_file, 'w', encoding='utf-8') as temp:
		entry_found = False
		with open(input_file, 'r', encoding='utf-8') as config:
			for line in config:
				changed, line = line_parser(line, items)
				entry_found = changed or entry_found
				temp.write(line)
		if not entry_found:
			_, line = line_parser(None, items, generate=True)
			temp.write(line)
	os.remove(input_file)
	os.rename(temp_file, input_file)

def generate_login(argv):
	if len(argv) > 1:
		config_file = argv[-1]
		if os.path.isfile(config_file):
			if not read_config_value(config_file, CONFIG_PASSWD):
				passwd = generate_password(PASSWORD_LENGTH)
				method = read_config_value(config_file, CONFIG_METHOD)
				project_path = os.path.dirname(config_file)
				if not project_path:
					project_path = '.'
				mkpasswd = '/'.join((project_path, 'host', 'bin/mkpasswd'))
				encrypted = encrypt_password(mkpasswd, method, passwd)
				shadow_file = '/'.join((project_path, 'target', 'etc/shadow'))
				write_entry(shadow_file, _shadow_parser, ('root', encrypted))
				write_entry(config_file, _config_parser, (CONFIG_PASSWD, passwd))
				print(f"{CONFIG_PASSWD} created")
			else:
				print(f"{CONFIG_PASSWD} exists")
		else:
			raise FileNotFoundError(config_file)
	else:
		raise RuntimeError('Missing argument: $(BR2_CONFIG)')

if __name__ == '__main__':
	sys.exit(generate_login(sys.argv))
