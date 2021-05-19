#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p out/
rm out/*

device="$1"
pmaports_dir="$(pmbootstrap config aports)"
source "$pmaports_dir"/device/*/device-"$device"/deviceinfo

# 'rdinit=/init' - run /init from the initramfs
# 'earlycon=msm_serial_dm,0xf991e000' - print output to the serial console as soon as possible
# 'cma=64m msm.vram=16m' - allocate some memory for the display, should be gone once iommu works
# 'drm.debug=31' - verbose logging in drm drivers
# 'clk_ignore_unused pd_ignore_unused' - keep unused clocks and power domains enabled
# 'PMOS_NO_OUTPUT_REDIRECT' - print postmarketOS ramdisk output to the serial console
cmdline='rdinit=/init earlycon=msm_serial_dm,0xf991e000 PMOS_NO_OUTPUT_REDIRECT clk_ignore_unused pd_ignore_unused cma=500m msm.vram=192m msm.allow_vram_carveout=1' # debug drm.debug=31'
cmdline='console=tty0 console=ttyMSM0,115200,n8 PMOS_NO_OUTPUT_REDIRECT deferred_probe_timeout=30 clk_ignore_unused pd_ignore_unused cma=500m msm.vram=192m msm.allow_vram_carveout=1'
cmdline='rdinit=/init PMOS_NO_OUTPUT_REDIRECT clk_ignore_unused pd_ignore_unused'
# TODO need better cmdline solution here - maybe file?

case "$deviceinfo_arch" in
    armv7)
        kernel_image="arch/arm/boot/zImage-dtb"
        ;;
    aarch64)
        kernel_image="arch/arm64/boot/Image.gz-dtb"
        ;;
    *)
        echo "ERROR: Architecture $deviceinfo_arch is not supported!"
        exit 1
        ;;
esac

mkbootimg \
    --base "$deviceinfo_flash_offset_base" \
    --pagesize "$deviceinfo_flash_pagesize" \
    --kernel_offset "$deviceinfo_flash_offset_kernel" \
    --ramdisk_offset "$deviceinfo_flash_offset_ramdisk" \
    --second_offset "$deviceinfo_flash_offset_second" \
    --tags_offset "$deviceinfo_flash_offset_tags" \
    --cmdline "$cmdline" \
    --kernel "$kernel_image" \
    --ramdisk "$DIR"/ramdisk-"$device".cpio.gz \
    -o out/mainline-boot.img
