# coding=latin-1
import sys
import argparse
import os
import struct
from struct import *

HEADER_SIZE = 40

def find_text(file, text):
    offset = 0
    while True:
        buf = file.read(len(text) * 2)
        if not buf:
            offset = -1
            break

        #print(buf)
        #pos = buf.find(text)
        text_buf = bytes(text, 'ascii')
        pos = buf.find(text_buf)
        if pos >= 0:
            offset += pos
            break

        offset += len(text)
        file.seek(-len(text), 1)

    return offset

def parse_header(file, offset):
    try:
        file.seek(offset)
        header = file.read(HEADER_SIZE)
        name, size1, size2 = unpack("<32sii", header)
    except:
        return None

    if size1 != size2:
        print("Sizes are not equal: " + name + " " + str(size1) + " " + str(size2))

    #return name.split('\0', 1)[0], size1
    return name.decode().split('\0', 1)[0], size1

def extract_file(file, out_file_info):
    outfile = open(out_file_info[0], "wb")
    
    file.seek(out_file_info[1])
    buf = file.read(out_file_info[2])
    if not buf:
        return
    
    outfile.write(buf)
    outfile.close()


parser = argparse.ArgumentParser(description="Get files packed inside the 70mai 4k OTA firmware")
parser.add_argument('filename', metavar='FILE', type=str, nargs='+', help='Firmware file')
parser.add_argument('--print_only','-p', action='store_true', default=False, help='Print file list only')
args = parser.parse_args()

# Open firmware file for reading
try:
    infile = open(args.filename[0], mode="rb+")
except:
    print("File " + args.filename[0] + " cannot be found.")
    sys.exit(1)

# Read header
FIRST_FILE_NAME = "config"
offset = find_text(infile, FIRST_FILE_NAME)
#print("Offset of 'config': " + str(offset))

if offset < 0:
    print("")
    sys.exit(1)

files = []
while True:
    file_info = parse_header(infile, offset)
    if file_info == None:
        break

    files.append( [file_info[0], offset + HEADER_SIZE, file_info[1]] )
    offset += HEADER_SIZE + file_info[1]

if args.print_only:
    print("Offset\tSize\t\tName")
    for info in files:
        print(str(info[1]) + "\t" + str(info[2]) + "\t\t" + info[0])
    sys.exit(0)

for info in files:
    print("Extracting " + info[0])
    extract_file(infile, info)
    
infile.close()
print("Done")



