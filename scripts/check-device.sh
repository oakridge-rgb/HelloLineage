#!/system/bin/sh
# check-device.sh — read-only probe for the Moto G Power 5G 2024 (cancunn)
# Run it from a PC:   adb push check-device.sh /data/local/tmp/
#                     adb shell su -c "sh /data/local/tmp/check-device.sh" > device-report.txt
# It changes nothing; it prints what ROUTE-B/ROUTE-A depend on.

line() { echo "------------------------------------------------------------"; }
sec()  { echo ""; echo "=== $1 ==="; }

sec "IDENTITY"
for p in ro.product.brand ro.product.model ro.product.device ro.build.version.release \
         ro.build.version.sdk ro.build.version.incremental ro.build.date \
         ro.product.first_api_level ro.vendor.api_level ro.vndk.version; do
    echo "$p = $(getprop $p)"
done

sec "TREBLE / PARTITIONING"
for p in ro.treble.enabled ro.boot.dynamic_partitions ro.boot.dynamic_partitions_retrofit \
         ro.boot.virtual_ab ro.boot.slot_suffix; do
    echo "$p = $(getprop $p)"
done

sec "KERNEL"
uname -a

sec "ROOT / DFROOT"
echo "id: $(id 2>/dev/null)"
echo "getenforce: $(getenforce 2>/dev/null)"
command -v su >/dev/null 2>&1 && echo "su at: $(command -v su)" || echo "su: not on PATH"
for d in /data/adb/ksu /data/adb/ksu/bin /data/adb/df; do
    [ -d "$d" ] && echo "present: $d"
done
[ -e /dev/df ] && echo "present: /dev/df (DFRoot marker)"
lsmod 2>/dev/null | grep -i dfroot && echo "dfroot module: loaded" || echo "dfroot module: not visible via lsmod (may still be loaded)"

sec "TOOLS THE CONTAINER ROUTE NEEDS"
for t in busybox resetprop 7zz idmap2 pivot_root; do
    found=""
    if command -v "$t" >/dev/null 2>&1; then found="$(command -v $t)"; fi
    [ -z "$found" ] && [ -x "/data/adb/ksu/bin/$t" ] && found="/data/adb/ksu/bin/$t"
    echo "$t: ${found:-MISSING}"
done

sec "BOOT-RELATED PARTITIONS"
if [ -d /dev/block/by-name ]; then
    ls /dev/block/by-name 2>/dev/null | grep -E '^(boot|init_boot|vendor_boot|vbmeta|super|system|product)' | sort | tr '\n' ' '
    echo ""
    echo "init_boot present: $(test -e /dev/block/by-name/init_boot_a && echo yes || echo no)"
else
    echo "/dev/block/by-name not accessible (run with su)"
fi

sec "IMS / RADIO DAEMONS (candidates for the container IMS gate)"
ps -A 2>/dev/null | grep -iE 'ims|ril|radio' | grep -v grep | awk '{print $NF}' | sort -u | head -20

sec "STORAGE"
df -h /data 2>/dev/null | tail -1
echo ""
echo "/data/local/tmp contents (leftover staging?):"
ls /data/local/tmp 2>/dev/null | head -10

sec "HOST LAUNCHER / ZYGOTE (for pre-flight reference)"
echo "current home app: $(cmd package resolve-activity --brief -c android.intent.category.HOME 2>/dev/null | tail -1)"
zygote_count=$(ps -A 2>/dev/null | grep -c zygote)
echo "zygote processes running: $zygote_count"

line
echo "Paste this whole report into a HelloLineage issue for help."
