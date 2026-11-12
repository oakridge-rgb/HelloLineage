# PORTING.md — Adapting OneLineage to Motorola (Hello UI)

A technical roadmap for making [OneLineage](https://github.com/WeWaffles/OneLineage)-style hot-switching work on a rooted Motorola phone. This is **research documentation** — nobody has shipped this port yet, and the upstream author is explicit that support for non-tested devices is extremely limited.

---

## 1. How OneLineage works (the reusable core)

OneLineage does **not** reflash anything. On a rooted Samsung (One UI 8.5):

1. A LineageOS 23.2 GSI (EXT4, vanilla or gapps) is downloaded and extracted under `/data/local/tmp`.
2. The GSI becomes the rootfs of a **userspace container**: `pivot_root` moves the running system into it.
3. The container runs its **own zygote and system_server** — a second Android userspace living beside the host's.
4. Host daemons that must stay alive keep running (notably `audioserver` / `cameraserver` — killing them deadlocks `AudioService`).
5. `return_to_oneui.sh` hands the screen back to the host system.

Generic, OEM-agnostic pieces (these should port mostly as-is):

| Mechanism | Notes |
|---|---|
| GSI staging under `/data/local/tmp` + extraction | Needs free space in `/data` |
| `pivot_root` container with own zygote / system_server | Core trick — Android-version sensitive |
| SELinux relabeling of staged `/data` | `system_data_file`, per-package `app_data_file` instead of `shell_data_file` |
| APEX handling | Host `/system/apex` and `/system_ext/apex` bind-mounted into the rootfs |
| Storage sweeper | Creates `/data/user/0`, `/data/user_de/0`, shared-storage dirs (no installd in guest) |
| App data ownership fix | Re-owns app dirs to the uid PackageManager assigned |
| Networking | Private routing table (4242), preferred APN switched to `IPV4V6`, never kill host `netd` |
| Boot diagnostics | Per-boot `/data/boot_failures.log` |
| Bluetooth pre-flight | Create `/data/misc/bluedroid` before guest boot to avoid a crash loop |
| adb seeding | Pre-set `Settings.Global.ADB_ENABLED`, copy host `adb_keys` into guest |

## 2. What is Samsung-specific and must be redone for Hello UI

### a) `services_patched.jar` / `framework_patched.jar`
Built against **One UI 8.5's** smali. Motorola's framework diverges differently: Moto Gestures/Moto Actions hooks, Moto's security patches, different vendor services. A port must decompile **Motorola's** `services.jar` / `framework.jar`, find the equivalent hook points, and rebuild. Expect this to be the single biggest time sink.

### b) `PermissionController_patched.apk`
Samsung's PermissionController references `android.permission.RANGING`, which the LineageOS 23.2 platform doesn't define — runtime permission dialogs crash. Motorola ships its own PermissionController version; the *same class* of bug is likely but with **different missing permissions**. Port step: diff Moto's PermissionController permission list against the LineageOS platform's `AndroidManifest.xml` / `framework-res` definitions and patch the gaps.

### c) Audio AIDL libs
The optional `libaudio*_aidl_conversion*_patched.so` binds exist because One UI's AIDL hashes differ from the GSI's. Motorola ships different lib versions — these patches may be unnecessary, or need different symbols. Known residual issue upstream: the guest binds the host's `media.codec`, whose AIDL hash mismatch burns CPU during codec enumeration — expect the same on Moto.

### d) IMS / SMS / calls
OneLineage keeps One UI's `imsd` alive and waits for voice registration before pivoting (`ims_watchdog.sh`). Motorola has its own IMS stack (Moto/Lenovo ims services in vendor). The port must identify the Moto IMS daemon(s), keep them running, and replicate the registration wait. **Even then, guest voice calls don't work upstream** — data and SMS piggyback on the host's IMS.

### e) Root model
Upstream accepts temp-root because Samsung (KNOX, flash counter). Motorola with an unlocked bootloader takes **permanent Magisk root** cleanly (patch `boot.img`/`init_boot.img` per the device). That's a genuine simplification for the port: the container can assume stable root, no re-rooting between boots.

## 3. Suggested port order

1. Pick a test device with an official LineageOS build for its codename (so you have a known-good fallback and can compare behavior against Route 1).
2. Unlock bootloader, root with Magisk.
3. Run the unmodified OneLineage APK + scripts — capture exactly where Hello UI diverges (`/data/boot_failures.log`, `logcat -b all`, bugreport).
4. Patch PermissionController first (most common class of guest crash).
5. Rebuild framework patches against Moto's jars.
6. Audio: test with host `audioserver` running (upstream's current approach) before touching AIDL libs.
7. IMS watchdog for the Moto IMS daemon last — SMS/data first, voice is out of scope.

## 4. Honest expectations

- Upstream, even on supported Samsung hardware: sessions can be kicked back to the host after minutes, DTMF tones glitch, deep-buffer audio stays disabled, developer options crash (no adb service registered in the guest).
- The upstream README says: tested only on S26 Ultra, base S26 and A25 (One UI 8.5); it "seems to require Android 16 to install without modifications"; variation between devices is large.
- **Reality check for Motorola users:** if your goal is "LineageOS on my Moto", Route 1 (official build) or Route 2 (GSI) gets you there today with working calls. Route 3's unique value is *keeping Hello UI installed* while demoing LineageOS without touching partitions — a great hack, but a research project on a new OEM.

## 5. References

- OneLineage (concept, scripts, patches): https://github.com/WeWaffles/OneLineage
- LineageOS official device wiki: https://wiki.lineageos.org/devices/
- TrebleDroid (maintained GSI ecosystem): https://github.com/TrebleDroid
- phh-Treble (original GSI project): https://github.com/phhusson/treble_experimentations
- Motorola bootloader unlock: https://motorola-global-portal.custhelp.com/app/standalone/bootloader
