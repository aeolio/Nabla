#!/usr/bin/python
# Generate a syslinux.cfg boot configuration, based on values configured 
# in Buildroot and Linux kernel configurations.
# Configuration files will be passed as (optional) program parameters, the 
# last parameter in the list will be used for storing the boot configuration

import io
import sys

port_id = None
port_type = 'console'
port_number = -1
port_baudrate = -1
processor_name = None
processor_count = 1
multiprocessing = False


main_config = [
	"DEFAULT nabla\n",
	"PROMPT 0\n",
	"\n",
	"LABEL nabla\n",
	"  SAY Booting Nabla O/S ...\n",
	"  KERNEL /boot/bzImage\n",
	]


def preamble():
	if port_type == 'serial':
		return 'SERIAL %d %d\n\n' % ( port_number, port_baudrate )
	return None


def kernel_parameters():
	s = '  APPEND'
	if multiprocessing or processor_count > 1:
		n = processor_count - 1
		s += ' isolcpus=nohz,domain,managed_irq,%d nohz_full=%d' % ( n, n )
	if port_type == 'serial':
		s += ' console=%s,%dn8' % ( port_id, port_baudrate )
	s += ' quiet\n'
	return s


def write_config(target):

	if False:
		print('port_id = %s' % port_id)
		print('port_type = %s' % port_type)
		print('port_number = %d' % port_number)
		print('port_baudrate = %d' % port_baudrate)
		print('processor_name = %s' % processor_name)
		print('processor_count = %d' % processor_count)
		print('multiprocessing = ', multiprocessing)

	with open(target, mode="w") as config_file:
		s = preamble()
		print(s, file=config_file, end='') if s else None
		for s in main_config:
			print(s, file=config_file, end='')
		s = kernel_parameters()
		print(s, file=config_file, end='')


def parse(text):
	global port_id
	global port_type
	global port_number
	global port_baudrate
	global processor_name
	global processor_count
	global multiprocessing

	try:
		if text and text[0] != '#':
			symbol, value = text.split('=')
			symbol = symbol.strip()
			value = value.lstrip().strip('\"')
			### from buildroot config
			if symbol == 'BR2_TARGET_GENERIC_GETTY_PORT':
				port_id = value
				if port_id[3] == 'S':
					port_type = 'serial'
					port_number = int(port_id[-1])
			if symbol == 'BR2_TARGET_GENERIC_GETTY_BAUDRATE':
				port_baudrate = int(value)
			### from kernel config
			if symbol == 'CONFIG_MGEODE_LX':
				processor_name = 'geode' if value == 'y' else None
			if symbol == 'CONFIG_SMP':
				multiprocessing = True if value == 'y' else False
			if symbol == 'CONFIG_NR_CPUS':
				processor_count = int(value)

	except ValueError:
		print(text)


def syslinux(config, target):

	for filename in config:
		with open(filename) as config_file:
			for line in config_file:
				line = parse(line.strip())

	write_config(target)


if __name__ == '__main__':
	target = sys.argv[-1]
	config = sys.argv[1:-1]
	sys.exit(syslinux(config, target))

