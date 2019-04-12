#!/bin/bash -x

rm out/*

# clk_ignore_unused pd_ignore_unused
cmdline='rdinit=/init PMOS_NO_OUTPUT_REDIRECT cma=64m msm.vram=16m drm.debug=31 clk_ignore_unused pd_ignore_unused'
mkbootimg --base 0 --pagesize 2048 --kernel_offset 0x00008000 --ramdisk_offset 0x02000000 --second_offset 0x00f00000 --tags_offset 0x00000100 --cmdline "$cmdline" --kernel zImage-dtb --ramdisk ramdisk.cpio.gz -o out/mainline-boot.img
