#!/bin/python

''' 
	Remove files that were installed by one or more packages
	from the Buildroot project tree.
'''

import os
import sys

from glob import glob

from colorama import Fore

BUILD_DIR = 'build'
LOCAL_MANIFEST = ".files-list"
GLOBAL_MANIFEST = "packages-file-list"

TARGETS = {
	'host',
	'staging',
	'target',
	}


def package_directory(package):
	''' Find package directory from package name '''
	pattern = '-'.join([ os.path.join(BUILD_DIR, package), '*' ])
	dirs = glob(pattern)
	if dirs:
		return os.path.basename(sorted(dirs)[0])
	return ''

def get_package_manifest(target):
	''' Construct package manifest file name '''
	return f"{LOCAL_MANIFEST}.txt" if target == "target" else f"{LOCAL_MANIFEST}-{target}.txt"

def get_global_manifest(target):
	''' Construct global manifest file name '''
	return f"{GLOBAL_MANIFEST}.txt" if target == "target" else f"{GLOBAL_MANIFEST}-{target}.txt"

def parse(line, package, target, file_list):
	''' Extract file name from one line of a manifest file '''
	s = line.split(',')
	name = s[0]
	path = s[1].strip()
	if name == package:
		file_path = os.path.join('.', target, path[2:])
		file_list.append(file_path)
	return file_list


def remove_package(package_name, package_dir):
	''' Remove files installed by one package '''

	installed_files = []

	for t in TARGETS:

		package_manifest = os.path.join(BUILD_DIR, package_dir, get_package_manifest(t))
		global_manifest = os.path.join(BUILD_DIR, get_global_manifest(t))

		# try build directory first
		if os.path.exists(package_manifest):
			with open(package_manifest, encoding='utf8') as src_file:
				for line in src_file:
					installed_files = parse(line, package_name, t, installed_files)
		# if the build directory is already deleted, try the global manifests
		elif os.path.exists(global_manifest):
			with open(global_manifest, encoding='utf8') as src_file:
				for line in src_file:
					installed_files = parse(line, package_name, t, installed_files)

	# remove every installed file
	for f in installed_files:
		# might already have been removed by a cleanup task
		if os.path.lexists(f):
			os.remove(f)
			print(f"{Fore.LIGHTBLACK_EX}deleted {f}{Fore.RESET}")


def remove_packages(argv):
	''' The main function of the module '''

	# argument(s) are package names
	packages = argv[1:]

	if not packages:
		print(f"{Fore.GREEN} Usage:\targv[0] package-list")
		print(f"\tpackage-list is a blank separated list of buildroot packages{Fore.RESET}")
		sys.exit(1)

	if not os.path.isdir(BUILD_DIR):
		print(f" {Fore.RED}error: run this from the project directory{Fore.RESET}")
		sys.exit(2)

	for package in packages:
		remove_package(package, package_directory(package))


if __name__ == '__main__':
	sys.exit(remove_packages(sys.argv))
