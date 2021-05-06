#!/bin/bash -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -f arch/arm/boot/zImage ]; then
    echo "Please run from the linux source tree with arch/arm/boot/zImage"
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

cat arch/arm/boot/zImage arch/arm/boot/dts/"$dtb".dtb > arch/arm/boot/zImage-dtb
"$DIR"/make_bootimg.sh "$device"
echo fastboot flash:raw boot out/mainline-boot.img
