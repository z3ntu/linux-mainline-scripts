#!/bin/bash -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -f arch/arm/boot/zImage ] && [ ! -f arch/arm64/boot/Image.gz ]; then
    echo "Please run from the linux source tree with arch/arm/boot/zImage or arch/arm64/boot/Image.gz"
    exit 1
fi

device="$1"
pmaports_dir="$(pmbootstrap config aports)"
source "$pmaports_dir"/device/*/device-"$device"/deviceinfo

dtb=""
if [ -n "$deviceinfo_dtb_mainline" ]; then
    dtb="$deviceinfo_dtb_mainline"
elif [ -n "$deviceinfo_dtb" ]; then
    dtb="$deviceinfo_dtb"
else
    echo "Couldn't find deviceinfo_dtb variable"
    exit 1
fi

case "$deviceinfo_arch" in
    armv7)
        cat arch/arm/boot/zImage arch/arm/boot/dts/"$dtb".dtb > arch/arm/boot/zImage-dtb
        kernel_image="arch/arm/boot/zImage-dtb"
        ;;
    aarch64)
        cat arch/arm64/boot/Image.gz arch/arm64/boot/dts/"$dtb".dtb > arch/arm64/boot/Image.gz-dtb
        kernel_image="arch/arm64/boot/Image.gz-dtb"
        ;;
    *)
        echo "ERROR: Architecture $deviceinfo_arch is not supported!"
        exit 1
        ;;
esac

if [ "$deviceinfo_bootimg_mtk_mkimage" == "true" ]; then
    mv arch/arm/boot/zImage-dtb arch/arm/boot/zImage-dtb.orig
    mtk_mkimage.sh KERNEL arch/arm/boot/zImage-dtb.orig arch/arm/boot/zImage-dtb
fi

# Read the cmdline for the device from a file
cmdline=$(cat "$DIR"/files/"$device".cmdline)

mkdir -p out/
rm -f out/*

mkbootimg \
    --base "$deviceinfo_flash_offset_base" \
    --pagesize "$deviceinfo_flash_pagesize" \
    --kernel_offset "$deviceinfo_flash_offset_kernel" \
    --ramdisk_offset "$deviceinfo_flash_offset_ramdisk" \
    --second_offset "$deviceinfo_flash_offset_second" \
    --tags_offset "$deviceinfo_flash_offset_tags" \
    --cmdline "$cmdline" \
    --kernel "$kernel_image" \
    --ramdisk "$DIR"/files/ramdisk-"$device".cpio.gz \
    -o out/mainline-boot.img

echo SUCCESS: out/mainline-boot.img
