# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=olive
device.name2=olivelite
device.name3=olivewood
device.name4=pine
device.name5=mi439
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;


## AnyKernel boot install
dump_boot;

ui_print "Mounting /vendor..."
mount -o rw,remount /vendor

vndk_version=$(file_getprop /vendor/build.prop ro.vendor.build.version.sdk)

if [ $vndk_version -lt 30 ]; then
    abort "Unsupported VNDK version. Aborting..."
fi

ui_print "Detecting WiFi HAL..."

wifi_hal=$(find /vendor/lib64 /vendor/lib -name "libwifi-hal.so" | head -n 1)
if grep -q "pronto_wlan.ko" $wifi_hal; then
    abort "Unsupported WiFi HAL. Aborting..."
fi

ui_print "Detecting camera HAL..."

if [[ ! -z "$(find /vendor/lib64 /vendor/lib -name '*lib2d*')" ]]; then
    patch_cmdline "prebuilt_camera_hal" "prebuilt_camera_hal"
else
    patch_cmdline "prebuilt_camera_hal" ""
fi

flash_boot;

ui_print " "

ui_print "Mounting /system..."
mount -o rw,remount /system

## Patches
# Prevent init from overriding kernel tweaks.
ui_print "Patching system's init..."
# IMO this is kinda destructive but works
find /system/etc/init/ -type f | while read file; do 
sed -Ei 's;[^#](write /proc/sys/(kernel|vm)/(sched|dirty|perf_cpu|page-cluster|stat|swappiness|vfs));#\1;g' $file
done
# IORap
ui_print "Patching system's build.prop..."
patch_prop /system/build.prop "ro.iorapd.enable" "true"
patch_prop /system/build.prop "iorapd.perfetto.enable" "true"
patch_prop /system/build.prop "iorapd.readahead.enable" "true"
patch_prop /system/build.prop "persist.device_config.runtime_native_boot.iorap_readahead_enable" "true"
patch_prop /system/build.prop "persist.device_config.runtime_native_boot.iorap_perfetto_enable" "true"
# Prevent init from overriding ZRAM algorithm
ui_print "Patching vendor's init..."
remove_line "/vendor/etc/init/hw/init.qcom.rc" "comp_algorithm" "global"
# Replace post_boot with ours.
ui_print "Pushing init.qcom.post_boot.sh..."
replace_file "/vendor/bin/init.qcom.post_boot.sh" "0755" "init.qcom.post_boot.sh"

write_boot;
## end boot install


# shell variables
#block=vendor_boot;
#is_slot_device=1;
#ramdisk_compression=auto;
#patch_vbmeta_flag=auto;

# reset for vendor_boot patching
#reset_ak;


## AnyKernel vendor_boot install
#split_boot; # skip unpack/repack ramdisk since we don't need vendor_ramdisk access

#flash_boot;
## end vendor_boot install

