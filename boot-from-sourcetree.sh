#!/bin/bash -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -f arch/arm/boot/zImage ]; then
    echo "Please run from the linux source tree with arch/arm/boot/zImage"
    exit 1
fi

cat arch/arm/boot/zImage arch/arm/boot/dts/qcom-msm8974-fairphone-fp2.dtb > arch/arm/boot/zImage-dtb
"$DIR"/make_bootimg.sh
echo fastboot flash boot out/mainline-boot.img
