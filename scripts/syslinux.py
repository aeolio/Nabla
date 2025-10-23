#!/bin/python

'''
	Generate a syslinux.cfg boot configuration, based on values configured
	in Buildroot and Linux kernel configurations.
	Configuration files will be passed as (optional) program parameters, the
	last parameter in the list will be used for storing the boot configuration
'''

import sys

from dataclasses import dataclass

@dataclass
class BootParameters:
	''' Holds the parameters parsed from Buildroot and Linux .config'''
	port_id : str
	port_type : str
	port_number : int
	port_baudrate : int
	processor_name : str
	processor_count : int
	multiprocessing : bool

	def __init__(self):
		self.port_id = None
		self.port_type = 'console'
		self.port_number = -1
		self.port_baudrate = -1
		self.processor_name = None
		self.processor_count = 1
		self.multiprocessing = False

main_config = [
	"DEFAULT nabla\n",
	"PROMPT 0\n",
	"\n",
	"LABEL nabla\n",
	"  SAY Booting Nabla O/S ...\n",
	"  KERNEL /boot/bzImage\n",
	]

DEBUG_OUTPUT = False


def preamble(p: BootParameters):
	''' for serial consoles, define baud rate '''
	if p.port_type == 'serial':
		return f"SERIAL {p.port_number} {p.port_baudrate}\n\n"
	return None


def kernel_parameters(p):
	''' generate kernel parameters '''
	s = '  APPEND'
	if p.multiprocessing or p.processor_count > 1:
		n = p.processor_count - 1
		s += f" isolcpus=nohz,domain,managed_irq,{n} nohz_full={n} rcu_nocbs={n}"
	if p.port_type == 'serial':
		s += f" console={p.port_id},{p.port_baudrate}n8"
	s += ' quiet\n'
	return s


def write_config(p, target_file):
	''' generate a syslinux.cfg file '''

	if DEBUG_OUTPUT:
		print(f"port_id = {p.port_id}")
		print(f"port_type = {p.port_type}")
		print(f"port_number = {p.port_number}")
		print(f"port_baudrate = {p.port_baudrate}")
		print(f"processor_name = {p.processor_name}")
		print(f"processor_count = {p.processor_count}")
		print(f"multiprocessing = {p.multiprocessing}")

	with open(target_file, mode="w", encoding='UTF8') as config_file:
		print(preamble(p), file=config_file, end='')
		for s in main_config:
			print(s, file=config_file, end='')
		s = kernel_parameters(p)
		print(s, file=config_file, end='')


def parse(p, text):
	''' extract information from buildroot or kernel config file '''
	try:
		if text and text[0] != '#':
			symbol, value = text.split('=')
			symbol = symbol.strip()
			value = value.lstrip().strip('\"')
			### from buildroot config
			if symbol == 'BR2_TARGET_GENERIC_GETTY_PORT':
				p.port_id = value
				if p.port_id[3] == 'S':
					p.port_type = 'serial'
					p.port_number = int(p.port_id[-1])
			if symbol == 'BR2_TARGET_GENERIC_GETTY_BAUDRATE':
				p.port_baudrate = int(value)
			### from kernel config
			if symbol == 'CONFIG_MGEODE_LX' and value == 'y':
				p.processor_name = 'geode'
			if symbol == 'CONFIG_SMP' and value == 'y':
				p.multiprocessing = True
			if symbol == 'CONFIG_NR_CPUS':
				p.processor_count = int(value)

	# line with second assignment in value part
	except ValueError:
		if DEBUG_OUTPUT:
			print(text)


def syslinux(config_files, target_file):
	''' Main function of the module '''
	p = BootParameters()
	for c in config_files:
		with open(c, encoding='UTF8') as config_file:
			for line in config_file:
				parse(p, line.strip())
	write_config(p, target_file)
	return 0


if __name__ == '__main__':
	# last parameter is the output file
	target = sys.argv[-1]
	# Linux and Buildroot config files
	configs = sys.argv[1:-1]
	sys.exit(syslinux(configs, target))
