#!/bin/bash -x

rm ../ramdisk.cpio.gz

find . -not -path "./.git/*" | cpio -o -H newc | gzip > ../ramdisk.cpio.gz
