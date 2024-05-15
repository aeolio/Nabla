#!/bin/python

import sys

# for details, see 
# https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files

# bit fields within cpuid
reserved1 = '31:28'
extended_family = '27:20'
extended_model = '19:16'
reserved2 = '15:14'
processor_type = '13:12'
family_code = '11:8'
model_number = '7:4'
stepping_id = '3:0'


def mask(s, bits):
	p = bits.split(':')
	first = int(p[0])
	last = int(p[1])
	# needs special handling for index '0'
	return s[-1-first:-last] if last else s[-1-int(p[0]):]


def main(cpuid):
	try:
		scale = 16	## number system hexadecimal
		width = 32
		s = bin(int(cpuid, scale))[2:].zfill(width)

		# fields in ucode files names
		family = int(mask(s, extended_family) + mask(s, family_code), 2)
		model = int(mask(s, extended_model) + mask(s, model_number), 2)
		stepping = int(mask(s, stepping_id), 2)

		s = '%02x-%02x-%02x' % (family, model, stepping)
		sys.stdout.write(s)
		sys.stdout.flush()

		return 0

	except:
		return 2


if __name__ == '__main__':
	sys.exit(main(sys.argv[1]))

