# How OneLineage / OneOS get a GSI "running like the actual OS"

Neither project flashes anything. The GSI never touches a partition. What they do is hijack the *userspace* of the running Android while keeping the kernel, modem, and hardware HALs of the host. Understanding the five layers below is what makes the Motorola port legible.

## Layer 0 — Root on a locked bootloader (DFRoot)

DFRoot exploits CVE-2026-43284 ("DirtyFrag"), a kernel page-cache write primitive: an AES-CBC IPSec transform decrypts attacker-shaped packets directly into the page cache of a file opened for `splice()`, letting it overwrite 16-byte-aligned blocks of a mapped shared library without write permission. DFRoot uses that to patch shellcode into `libc++.so`, which — triggered via init's own reaping path — loads `dfroot.ko` through `/vendor/bin/insmod` in the `vendor_modprobe` SELinux domain. The kernel module then:

- writes `false` to `selinux_state` → **SELinux globally permissive**,
- launches the bootstrap that starts your SU manager's daemon (KernelSU-compatible).

Two properties of this root matter enormously for the container method:

1. **SELinux permissive** — a guest GSI userspace is labelled for a different policy; enforcing mode would drown it in EACCES. OneLineage's own scripts run `setenforce 0` for the whole session. DFRoot gives this for free.
2. **A KernelSU-compatible `su` + busybox** at `/data/adb/ksu/bin/` — the same paths OneLineage's scripts already probe.

This is the exact ingredient set the Samsung projects assume, and DFRoot provides it on `cancunn` with the bootloader untouched.

## Layer 1 — Stage the GSI in /data

A LineageOS GSI (an ARM64 A/B `system.img`, roughly 1.3 GB compressed / 4–5 GB extracted) is downloaded to the phone and extracted to a staging folder such as `/data/local/tmp/lineage_stage/rootfs` using a bundled static 7-zip binary. `/data` is writable without unlocking anything, so from the bootloader's point of view nothing happened.

OneLineage uses the EXT4 builds (VANILLA or GAPPS) of MisterZtr's LineageOS 23.2 GSIs. This is the same GSI family a normal Treble device would flash — it just never gets flashed.

## Layer 2 — Host preparation (the takeover preamble)

The switch script (`switch_to_lineage.sh`) does, in order:

1. **SELinux permissive** for the whole session (see Layer 0).
2. **IMS gate.** The guest GSI has no IMS stack of its own, so the modem's IMS registration — the thing SMS and voice registration hang off — belongs to the host's IMS daemon (`imsd` on Samsung). The script waits for voice registration (`mVoiceRegState=0`) before touching anything, and later runs an IMS keep-alive. Killing the host IMS daemon is what made SMS arrive 20–40 minutes late in early testing.
3. **ADB watchdog.** The guest's own UsbService rewrites `sys.usb.config` during boot and can drop the `adb` function; a background loop on the host side keeps `adbd` and the USB gadget alive, because adb is your only way back in while the guest is up.
4. **Protect the host.** Pin the host launcher so it survives, disable RescueParty (`persist.sys.disable_rescue_party=1`), set `ro.control_privapp_permissions=log` so the GSI's privapp-permission mismatches log instead of fatal.
5. **Stop the host zygote.** Host `audioserver`, `cameraserver`, `netd` and the IMS daemon stay running (early versions stopped them and deadlocked audio); only the Java world is shut down.

## Layer 3 — pivot_root into the GSI

`master_inner.sh` runs inside the staged rootfs:

- `mount --make-rprivate /` then **`pivot_root . postinstall`** (with a bind-mount-on-itself fallback) — the staged GSI folder becomes `/`.
- proc/sys/dev are mounted; host app data is bound in so the guest sees the same `/data/data`: `/data/user/0` over `/data/data`, plus the `data_mirror` layout zygote expects (`data_ce`, `data_de`, profiles).
- Shared storage: `/data/media/0` bound over `/storage/emulated/0` and `/mnt/user/0/emulated`.
- Guest **SurfaceFlinger** (its stderr goes to `/dev/null` — unbounded shader-dump logs once filled `/data` in minutes), **bootanimation**, **vold**, and **wificond** are started; wificond registers with the *host's* Wi-Fi HAL, which is still up.
- Gesture-nav and SystemUI overlays get idmaps generated with `idmap2 --ignore-overlayable` (OMS would otherwise silently drop overlays that aren't declared `overlayable`).
- An app-storage sweeper creates `/data/user/0`-style directories for apps newly installed inside the guest — the guest has no `installd`.

Host APEXes (`/system/apex`, `/system_ext/apex`) are bound into the rootfs so PackageManagerService can scan them; this is also what drags the *host's* PermissionController into the guest — the root of OneLineage's Samsung-specific patches (below).

## Layer 4 — Guest zygote and system_server

A tiny static launcher (`zygote_exec`) starts the **GSI's own zygote**, which forks system_server for the LineageOS framework. From here the phone presents the GSI: LineageOS SystemUI, launcher, settings, apps. The host kernel, RIL, modem, audio/camera HALs and the IMS daemon underneath are all still the Moto's. Returning (`return_to_oneui.sh`) re-enforces SELinux, restarts the host zygote, and tears the guest down — or you just reboot, which trivially undoes everything because no partition was touched.

## What is Samsung-specific (and therefore must change for Motorola)

| OneLineage/OneOS piece | Why it exists | On the Moto |
| --- | --- | --- |
| `services_patched.jar` / `framework_patched.jar` bind-mounts | One UI's framework jars needed shims | Drop — Moto's jars stay untouched; the guest uses the GSI's own framework |
| `PermissionController_patched.apk` (removes `RANGING`) | Host APEX bind pulls Samsung's PermissionController into the guest, which references a permission the LineageOS 23.2 platform doesn't define → crash loop | The bind still pulls **Motorola's** PermissionController into the guest; a similar permission-version mismatch is possible. If PermissionController crashes in the guest, the fix pattern is the same (patch the reference out, or bind the GSI's own APEX on top) |
| Patched audio AIDL libs | One UI 8.5 AIDL hash drift | Not shipped; if audio deadlocks, keep host `audioserver` running (OneLineage's current approach) rather than patching |
| `imsd` watchdog | Samsung's IMS daemon name | Motorola's IMS daemons have different names — find them with `ps -A | grep -i ims` on your device (the check script prints this) and adapt the gate/keep-alive |
| Device/manufacturer checks in the apps | They gate on Samsung models | OneOS refuses non-Samsung outright; OneLineage's app is a PoC. For a phone-shaped result you fork the app and relax the checks (see Route B) |

## The deltas in OneOS

OneOS is the hardened rewrite: Kotlin app, per-system guest images built with MysticGSI (ColorOS, HyperOS, OxygenOS, Pixel images...), pre-boot safety checks, verbose boot handoff, a guest screen lock implemented inside the guest (0.4.95), and a hardware shortcut back to One UI (Volume Up + Down for 3 s). Its compatibility docs are the best public source on *why guest systems fail* (IMS ownership, AIDL drift between guest and host HALs, guest reaching host data). Everything it refuses is refused by a model table — every entry is `SM-*`.

## Why this ends up feeling like "the actual OS"

The guest owns the entire Java userspace: its own framework, SystemUI, launcher, settings, package manager, app lifecycle. There is no window-in-a-window; when it is up, the phone *is* LineageOS as far as the screen is concerned. The things that betray it are the things the host still owns: radio (IMS/voice), some audio paths, and USB state — which is exactly where the porting effort concentrates.
