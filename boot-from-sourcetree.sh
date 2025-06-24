#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -f arch/arm/boot/zImage ] && [ ! -f arch/arm64/boot/Image.gz ]; then
    echo "Please run from the linux source tree with arch/arm/boot/zImage or arch/arm64/boot/Image.gz"
    exit 1
fi

function usage() {
    echo "Usage: $0 [OPTION] device"
    echo "Assembles boot.img from compiled kernel."
    echo "Removes old kernel modules from ramdisk, replace with specified ones."
    echo "Modifies deviceinfo_modules_initfs so modules are loaded automatically (disable with --no-module-load)"
    echo
    echo " -m, --modules=MODULES        comma-separated list of modules to use"
    echo " -p, --modules-pmaports       take module list from device package"
    echo " -e, --extra-modules=MODULES  comma-separated list of modules to append to existing list (to be used with --modules-pmaports)"
    echo " --no-module-load             disable automatic loading of modules in ramdisk"
    echo " --extra-files                comma-separated list to copy into the ramdisk into /extra-files/"
    echo " -d, --debug-shell            boot into debug-shell"
    echo " --hook=HOOK                  enable specified hook"
    echo " -h, --help                   show this help text"
}

LONGOPTS=modules-pmaports,modules:,extra-modules:,no-module-load,extra-files:,debug-shell,help,hook:
OPTIONS=pm:e::dh

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [ "$?" -ne 0 ]; then
    usage
    exit 2
fi
eval set -- "$PARSED"

arg_modules_pmaports=0
arg_modules=
arg_extra_modules=
arg_extra_files=
no_module_load=0
modules=
hook=
debug_shell=0
while true; do
    case "$1" in
        -p|--modules-pmaports)
            arg_modules_pmaports=1
            shift
            ;;
        -m|--modules)
            arg_modules="$2"
            shift 2
            ;;
        -e|--extra-modules)
            arg_extra_modules="$2"
            shift 2
            ;;
        --no-module-load)
            no_module_load=1
            shift
            ;;
        --extra-files)
            arg_extra_files="$2"
            shift 2
            ;;
        -d|--debug-shell)
            debug_shell=1
            shift
            ;;
        --hook)
            hook="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Arg error"
            usage
            exit 3
            ;;
    esac
done

if [ $# -ne 1 ]; then
    echo "Need to provide device name"
    usage
    exit 4
fi

device="$1"
pmaports_dir="$(pmbootstrap config aports)"
device_dir="$(ls -d "$pmaports_dir"/device/*/device-"$device"/)"
source "$device_dir"/deviceinfo

# Process more arguments
if [ "$arg_modules_pmaports" -eq 1 ]; then
    if [ -f "$device_dir"/modules-initfs.mainline ]; then
        modules="$(tr '\n' ' ' < "$device_dir"/modules-initfs.mainline)"
    elif [ -f "$device_dir"/modules-initfs ]; then
        modules="$(tr '\n' ' ' < "$device_dir"/modules-initfs)"
    else
        echo "Failed to find deviceinfo_modules_initfs"
        exit 5
    fi
fi
if [ -n "$arg_modules" ]; then
    modules="${arg_modules//,/ }"
fi
if [ -n "$arg_extra_modules" ]; then
    modules="$modules ${arg_extra_modules//,/ }"
fi

dtb=""
if [ -n "$deviceinfo_dtb_mainline" ]; then
    dtb="$deviceinfo_dtb_mainline"
elif [ -n "$deviceinfo_dtb" ]; then
    dtb="$deviceinfo_dtb"
else
    echo "Couldn't find deviceinfo_dtb variable"
    exit 1
fi

# Consider header_version to be 0 when not set, following AOSP docs
if [ -z "$deviceinfo_header_version" ]; then
    deviceinfo_header_version=0
fi

if [ "$deviceinfo_header_version" -gt 2 ]; then
    echo "Unsupported boot image header version $deviceinfo_header_version"
    exit 1
fi

case "$deviceinfo_arch" in
    armv7)
        # TODO: Remove hardcoded 'qcom' path, use globs or something
        cat arch/arm/boot/zImage arch/arm/boot/dts/qcom/"$dtb".dtb > arch/arm/boot/zImage-dtb
        kernel_image="arch/arm/boot/zImage-dtb"
        ;;
    aarch64)
        if [ "$deviceinfo_header_version" -eq 2 ]; then
            kernel_image="arch/arm64/boot/Image.gz"
        else
            cat arch/arm64/boot/Image.gz arch/arm64/boot/dts/"$dtb".dtb > arch/arm64/boot/Image.gz-dtb
            kernel_image="arch/arm64/boot/Image.gz-dtb"
        fi
        ;;
    *)
        echo "ERROR: Architecture $deviceinfo_arch is not supported!"
        exit 1
        ;;
esac

if [ -n "$deviceinfo_bootimg_mtk_label_kernel" ]; then
    mv "$kernel_image" "$kernel_image.orig"
    mtk_mkimage.sh "$deviceinfo_bootimg_mtk_label_kernel" "$kernel_image.orig" "$kernel_image"
fi

# Read the cmdline for the device from a file
cmdline=$(cat "$DIR"/files/"$device".cmdline)

if [ "$debug_shell" -eq 1 ]; then
    echo "Enabling boot into debug-shell."
    cmdline="$cmdline pmos.debug-shell"
fi

mkdir -p out/
rm -rf out/*

ramdisk="$DIR"/files/ramdisk-"$device".cpio.gz_debug

# Copy a module and all its dependencies into the ramdisk
function copy_module {
    module=$1
    results=($(echo "$all_modules" | grep "/$module.ko" || true))
    if [ ${#results[@]} -ne 1 ]; then
        echo "Didn't find one result for '$module.ko': ${results[@]}"
        exit 1
    fi

    dst=out/ramdisk/lib/modules/$KERNELRELEASE/kernel/${results[0]}
    mkdir -p "$(dirname "$dst")"
    cp "${results[0]}" "$dst"

    depends_str=$(modinfo --field=depends "${results[0]}")
    depends=(${depends_str//,/ })

    for depend in "${depends[@]}"; do
        copy_module "$depend"
    done
}

function handle_ramdisk_modules() {
    # Remove existing modules and create path for new ones
    KERNELRELEASE=$(cat include/config/kernel.release)
    rm -rf out/ramdisk/lib/modules
    mkdir -p out/ramdisk/lib/modules/"$KERNELRELEASE"/kernel/

    cp modules.order modules.builtin modules.builtin.modinfo out/ramdisk/lib/modules/"$KERNELRELEASE"/

    # Get all modules in source tree for later operation
    all_modules="$(find . -not -path "./out/*" -name "*.ko")"

    if [ -n "$modules" ]; then
        echo "Copying modules: $modules"
    else
        echo "Copying no modules."
    fi
    for module in $modules; do
        copy_module "$module"
    done

    # Generate modules.dep and map files
    depmod -b out/ramdisk "$KERNELRELEASE"

    if [ "$no_module_load" -eq 0 ]; then
        echo "$modules" | tr ' ' '\n' > out/ramdisk/lib/modules/initramfs.load
    fi
}

function handle_ramdisk_hooks() {
    # Remove existing hooks
    rm -f out/ramdisk/hooks/*

    if [ -z "$hook" ]; then
        echo "No hooks specified."
    else
        echo "Hook: $hook"
        cp -v "$pmaports_dir"/main/postmarketos-mkinitfs-hook-"$hook"/*.sh out/ramdisk/hooks/
    fi
}

function handle_ramdisk_files() {
    extra_files="${arg_extra_files//,/ }"
    mkdir -p out/ramdisk/extra-files
    for file in $extra_files; do
        cp -v "$file" out/ramdisk/extra-files/
    done
}

function handle_ramdisk() {
    # Extract original ramdisk
    # TODO: Breaks with MTK ramdisk header
    mkdir -p out/ramdisk
    pushd out/ramdisk >/dev/null
    gunzip -c "$ramdisk" | cpio --extract --quiet
    popd >/dev/null

    handle_ramdisk_modules
    handle_ramdisk_hooks
    handle_ramdisk_files

    # Repack ramdisk
    pushd out/ramdisk >/dev/null
    "$DIR"/make_ramdisk.sh
    popd >/dev/null

    if [ -n "$deviceinfo_bootimg_mtk_label_ramdisk" ]; then
        mv out/ramdisk.cpio.gz out/ramdisk.cpio.gz.orig
        mtk_mkimage.sh "$deviceinfo_bootimg_mtk_label_ramdisk" out/ramdisk.cpio.gz.orig out/ramdisk.cpio.gz
    fi

    ramdisk=out/ramdisk.cpio.gz
}

handle_ramdisk

extra_args=()
if [ -n "$deviceinfo_header_version" ]; then
    extra_args+=("--header_version" "$deviceinfo_header_version")
    if [ "$deviceinfo_header_version" -eq 2 ]; then
        extra_args+=("--dtb" "arch/arm64/boot/dts/$dtb.dtb")
        extra_args+=("--dtb_offset" "$deviceinfo_flash_offset_dtb")
    fi
fi

mkbootimg \
    --base "$deviceinfo_flash_offset_base" \
    --pagesize "$deviceinfo_flash_pagesize" \
    --kernel_offset "$deviceinfo_flash_offset_kernel" \
    --ramdisk_offset "$deviceinfo_flash_offset_ramdisk" \
    --second_offset "$deviceinfo_flash_offset_second" \
    --tags_offset "$deviceinfo_flash_offset_tags" \
    --cmdline "$cmdline" \
    --kernel "$kernel_image" \
    --ramdisk "$ramdisk" \
    $deviceinfo_bootimg_custom_args \
    "${extra_args[@]}" \
    -o out/mainline-boot.img

echo SUCCESS: out/mainline-boot.img
