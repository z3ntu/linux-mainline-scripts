#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p out/
rm out/*

# 'rdinit=/init' - run /init from the initramfs
# 'earlycon=msm_serial_dm,0xf991e000' - print output to the serial console as soon as possible
# 'cma=64m msm.vram=16m' - allocate some memory for the display, should be gone once iommu works
# 'drm.debug=31' - verbose logging in drm drivers
# 'clk_ignore_unused pd_ignore_unused' - keep unused clocks and power domains enabled
# 'PMOS_NO_OUTPUT_REDIRECT' - print postmarketOS ramdisk output to the serial console
cmdline='rdinit=/init earlycon=msm_serial_dm,0xf991e000 PMOS_NO_OUTPUT_REDIRECT clk_ignore_unused pd_ignore_unused cma=500m msm.vram=192m' # debug drm.debug=31'
mkbootimg \
    --base 0 \
    --pagesize 2048 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x02000000 \
    --second_offset 0x00f00000 \
    --tags_offset 0x00000100 \
    --cmdline "$cmdline" \
    --kernel arch/arm/boot/zImage-dtb \
    --ramdisk "$DIR"/ramdisk.cpio.gz \
    -o out/mainline-boot.img
