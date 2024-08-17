#!/bin/python

import os
import sys

file_lists = [
	'packages-file-list.txt',
	'packages-file-list-host.txt',
	'packages-file-list-staging.txt',
	]

BASE_NAME = os.path.splitext(file_lists[0])[0]


def get_target(filename):
	name, ext = os.path.splitext(filename)
	dir = name.replace(BASE_NAME, '')
	dir = 'target' if not dir else dir.lstrip('-')
	return dir

def parse(line, packages, target, file_list):
	s = line.split(',')
	name = s[0]
	path = s[1].strip()
	if name in packages:
		file_path = os.path.join('./', target, path[2:])
		file_list.append(file_path)
	return file_list


def remove_package(argv):

	# argument(s) are package names
	packages = argv[1:]

	if not packages:
		print('Usage: argv[0] package-list')
		print('\tpackage-list is a blank separated list of buildroot packages')

	installed_files = []

	for f in file_lists:

		# this should be run from the project directory
		filename = os.path.join('build', f)
		target = get_target(f)

		with open(filename) as src_file:
			for line in src_file:
				installed_files = parse(line, packages, target, installed_files)

	# remove every installed file
	for f in installed_files:
		# might already have been removed by a cleanup task
		if os.path.lexists(f):
			os.remove(f)
			print('deleted %s' % f)


if __name__ == '__main__':
	sys.exit(remove_package(sys.argv))
