#!/bin/bash -e

rm -f ../ramdisk.cpio.gz

find . -not -path "./.git/*" | cpio --quiet -o -H newc | gzip > ../ramdisk.cpio.gz
