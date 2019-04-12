#!/bin/bash -ex

if [ $(basename $PWD) != "linux" ]; then
    echo "Please run from the linux source tree with arch/arm/boot/zImage"
    exit 1
fi

cat arch/arm/boot/zImage arch/arm/boot/dts/qcom-msm8974-fairphone-fp2.dtb > ../zImage-dtb
cd ..
./make_bootimg.sh
cd out
sign_img mainline-boot.img
fastboot boot mainline-boot.img.signed
