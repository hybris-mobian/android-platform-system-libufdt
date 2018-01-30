#!/bin/bash

if [ -z "${ANDROID_HOST_OUT}" ]; then
  echo 'ANDROID_HOST_OUT not set. Please run lunch'
  exit 1
fi

ANDROID_VTS_HOST_BIN_LOCATION=${ANDROID_HOST_OUT}/vts/android-vts/testcases/host/bin

adb root

tmpdir=$(mktemp -d)
trap 'rm -rf ${tmpdir};' EXIT

cd $tmpdir

#find out the location to read the DTBO image from
boot_suffix=$(adb wait-for-device shell getprop ro.boot.slot_suffix)
dtbo_partition="/dev/block/bootdevice/by-name/dtbo"
dtbo_path=$dtbo_partition$boot_suffix

#read the dtbo image and the final device tree from device
adb pull $dtbo_path dtbo.img > /dev/null
adb pull /sys/firmware/fdt final_dt > /dev/null

#decompile the DTBO image
mkdtimg_path="${ANDROID_VTS_HOST_BIN_LOCATION}/mkdtimg"
$mkdtimg_path dump dtbo.img -b dumped_dtbo > /dev/null

#Get the index of the overlay applied from the kernel command line
overlay_idx=$(adb shell cat /proc/cmdline | grep -o "androidboot.dtbo_idx=\w*" | cut -d "=" -f 2)

#verify that the overlay was correctly applied
verify_bin_path="${ANDROID_VTS_HOST_BIN_LOCATION}/ufdt_verify_overlay_host"
$verify_bin_path final_dt dumped_dtbo.$overlay_idx
result=$?

if [[ "$result" -eq "0" ]]; then
  echo "Overlay was verified successfully"
else
  echo "Incorrect overlay application"
fi

exit $result
