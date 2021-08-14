#!/bin/bash -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p out/
rm -f out/*

device="$1"
pmaports_dir="$(pmbootstrap config aports)"
source "$pmaports_dir"/device/*/device-"$device"/deviceinfo

# Read the cmdline for the device from a file
cmdline=$(cat "$DIR/$device.cmdline")

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
