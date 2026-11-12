# Route B — Container GSI on the Moto G Power 5G 2024 (locked bootloader, DFRoot)

This is the OneLineage/OneOS method applied to `cancunn`. The bootloader stays locked; the GSI lives in `/data`; when the guest is up, the phone runs LineageOS with its own launcher, settings and apps; a reboot always returns you to Hello UI.

Read [HOW-IT-WORKS.md](HOW-IT-WORKS.md) first — this guide references its layers.

## 0. Prerequisites

- **DFRoot root is active** and a KernelSU-compatible manager grants `su` (DFRoot "Start on Boot" enabled means root survives reboots; otherwise re-run DFRoot after each boot).
- USB debugging works (`adb devices` shows the phone, and `adb shell su -c id` prints `uid=0`).
- **At least 8 GB free in `/data`** (GSI archive + extracted rootfs + logs + headroom).
- Screen lock removed, data backed up. Seriously.
- Run `check-device.sh` (repo root) and keep the output — it confirms codename, Treble, root, SELinux mode, busybox/resetprop, and the IMS daemon names you will need.

## 1. Get the GSI

Same source OneLineage credits: **[MisterZtr GSI on SourceForge](https://sourceforge.net/projects/misterztr-gsi/)** ([GitHub builds](https://github.com/MisterZtr/LineageOS_gsi/releases)).

- Pick **LineageOS 23.2 (Android 16), arm64, A/B** — the file names carry the Treble letters (`gsi_arm64_bvS`/`bvNE` etc. — `b` = A/B, `vN` = VNDK-lite/APEX rendering variants; the `ab` arm64 builds are what this device profile takes).
- Prefer the **EXT4** build over EROFS (OneLineage uses EXT4; the staging scripts bind and relabel files inside the extracted tree).
- **VANILLA** (no Google apps) is safer for a first boot; GAPPS is the same image plus Play — try it on the second run.
- Expect ~1.3 GB `.7z` → ~4–5 GB extracted.

Transfer to the phone (USB, or download in browser) into `/data/local/tmp/`.

## 2. The port — what to change in OneLineage for `cancunn`

Fork [WeWaffles/OneLineage](https://github.com/WeWaffles/OneLineage). Its README explicitly invites porting: the app is the wrapper, everything real is in `assets/*.sh`. Adapt as follows, then build with its `build_apk.sh` (JDK 17, Android SDK build-tools 34, `ANDROID_SDK_ROOT` set — the script creates a dev keystore on first use and writes `out/OneLineage.apk`).

### 2a. Strip the Samsung-only parts

In `master_prepare.sh` / `switch_to_lineage.sh`:

- Remove the bind-mounts of `services_patched.jar`, `framework_patched.jar`, `PermissionController_patched.apk`, and the patched audio `.so` files. Those are One UI fixes; on the Moto the guest should run the GSI's own jars and the Motorola host APEXes as-is.
- Keep the **APEX binds** (`/system/apex`, `/system_ext/apex` into the rootfs) — without them PackageManagerService dies in `scanApexPackages` on any vendor, not just Samsung.

### 2b. Replace the radio glue

- Samsung waits on `imsd`. Motorola's IMS daemons are named differently (the check script prints `ps -A | grep -i ims` — expect several `ims*`/vendor radio processes). Put those names into the IMS gate and keep-alive, and keep the gate logic: wait for `dumpsys telephony.registry` to show `mVoiceRegState=0` before pivoting.
- Keep the **adb watchdog** verbatim — the failure mode it handles (guest UsbService rewriting `sys.usb.config`) is generic Android, not Samsung.
- Keep **`netd` untouched** and the private routing-table approach (table 4242) — the guest's ConnectivityService cannot program the host's netd on any device.

### 2c. Device values for `cancunn`

- Staging path, busybox and resetprop probing in OneLineage already cover KernelSU layouts (`/data/adb/ksu/bin/`), which is what DFRoot-based setups have.
- The device is ARM64, A/B, dynamic partitions — no partition work is needed at all for this route.
- Host is on Android 15 (the Android 15 Hello UI rollout for this model started January 2025; check `ro.build.version.sdk` — the check script prints it). OneLineage's unmodified flow expects an Android 16 host (One UI 8.5). That is the single biggest *risk* in this port: expect an API-version gap between host userspace and the Android 16 guest. If the guest dies early in `system_server`, the first thing to try is a GSI built for a closer API level (MisterZtr publishes Android 15 branch builds too), and only then deeper script surgery.

### 2d. First-boot expectations (from the Samsung testing, likely to recur here)

| Symptom | Cause | First fix |
| --- | --- | --- |
| Guest crashes in PermissionController | host APEX pulled in with version-drifted permission defs | bind the GSI's own PermissionController APEX over the host's, or patch the unknown permission reference |
| No voice calls in guest | guest has no IMS stack; this is also OneLineage's known state on Samsung | data + (with keep-alive) SMS is the realistic target |
| Wi-Fi flaky at start | guest wificond registering against host HAL | keep the OneLineage ordering: stop host wificond, start guest wificond before WifiService init |
| Return to Hello UI hangs / black screen | host zygote not restarted cleanly | reboot — costless on this route |
| Guest boot loops after ~1 min | OneOS fixed several takeover-life timers; container session lifetime is their active battleground | read `/data/boot_failures.log` and logcat; expect iteration |

## 3. Run order (what the app does, manually or via the ported APK)

1. `su` available, `getenforce` → `Permissive` (DFRoot module loaded).
2. Stage: extract the GSI `.7z` into `/data/local/tmp/lineage_stage/rootfs`, relabel the tree (`system_data_file` etc. per OneLineage's `master_prepare.sh`), bind the host APEXes.
3. Preamble: IMS gate (Moto daemon names), adb watchdog, RescueParty off, privapp permissions to `log`, host launcher protected.
4. Stop host zygote → `pivot_root` into the rootfs → bind app-data/storage mirrors → start guest surfaceflinger/vold/wificond → generate overlay idmaps → start guest zygote via `zygote_exec`.
5. LineageOS boots to its home screen. Apps installed in the guest become launchable via the storage sweeper.
6. Return: reboot, or the return script (re-enforce SELinux, restart host zygote).

## 4. Escalation path if the port stalls

- Read `/data/boot_failures.log` (OneLineage writes per-boot diagnostics) and `logcat` from the adb watchdog window.
- Compare against OneOS's public per-system failure docs (`docs/compatibility.md`, `docs/guest-runtime.md`, `docs/samsung-ims-in-guest.md` in their repo) — the failure taxonomy transfers even though the devices differ.
- Ask on the OneOS Telegram (their README links it) for the container mechanics; port-specific questions belong in an issue here.
- Worst case: reboot. Nothing is flashed, so "bricked" is not on the table for this route — worst realistic case is a factory reset if `/data` got filled or app data got confused.
