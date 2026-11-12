# HelloLineage

Run a **LineageOS GSI** on the **Moto G Power 5G (2024)** the same way [OneLineage](https://github.com/WeWaffles/OneLineage) and [OneOS](https://github.com/fahadalijaved/OneOS) do it on Samsung: as a second system that behaves like the actual OS — boots to its own home screen, runs its own apps — **without flashing anything**. A real-flash route (GSI as the literally-flashed OS) is documented too, for when the bootloader gets unlocked.

- **Phone:** Moto G Power 5G 2024, model XT2415, codename `cancunn`, MediaTek Dimensity 7020, running Motorola Hello UI (the skin this device ships with — Motorola's equivalent of what One UI is on Samsung)
- **Root:** DFRoot (DirtyFrag, CVE-2026-43284) — kernel-module root that works with the **bootloader still locked**, paired with any KernelSU-compatible manager
- **Goal:** a LineageOS GSI running like the phone's real OS

## The one-paragraph summary

With a locked bootloader you cannot flash any partition — so a GSI cannot be installed the classic way. OneLineage and OneOS work around exactly this on Samsung phones: they stage the GSI image inside `/data` (a normal, writable folder), stop the host's zygote, `pivot_root` into the staged GSI so it becomes the running root filesystem, and start a second Android userspace (its own zygote, system_server, SurfaceFlinger) on top of the same kernel, modem and hardware. Nothing is flashed, so a reboot — or the return script — brings Hello UI straight back. This repo maps that method onto a Motorola device with DFRoot.

## Two routes

| | Route B — Container (OneLineage method) | Route A — Real flash |
| --- | --- | --- |
| Bootloader | stays **locked** | must be **unlocked** (Motorola portal) |
| How | GSI staged in /data, pivoted as container | GSI written to the system partition via fastbootd |
| GSI feels like | the OS while it runs; switch back to Hello UI any time | the OS, permanently, with normal boot flow |
| Calls/SMS in GSI | degraded on the Samsung projects; on Moto expect to iterate | normal |
| Reversible | yes — nothing is modified on any partition | yes — full firmware restore, but no re-lock |
| Doc | [docs/ROUTE-B-CONTAINER.md](docs/ROUTE-B-CONTAINER.md) | [docs/ROUTE-A-FLASH-GSI.md](docs/ROUTE-A-FLASH-GSI.md) |

With DFRoot in hand, **Route B is the one that works right now** on this phone, and it is what "like how OneOS and OneLineage is" means in practice. Route A is the cleaner end state if you are willing to unlock.

## What is actually tested (honesty first)

- OneLineage itself is a proof of concept, tested **only on rooted Samsung phones** (Galaxy S26 Ultra, base S26, A25 — One UI 8.5 / Android 16). Its README says so and expects porting work for other devices.
- OneOS (its evolved Kotlin successor) **refuses every non-Samsung phone** at its compatibility check — that is why this repo exists instead of "just use OneOS".
- No confirmed public report of a GSI (flashed or container) on `cancunn` was found at the time of writing. The device is a standard ARM64 A/B Treble device with dynamic partitions, which is the hardware profile GSIs target, but nobody has published a result yet.
- So treat Route B on this phone as a **documented port plan with a working template**, not a one-click APK. Expect iteration, logs, and some dead ends. Route A is the boring, well-trodden path on Motorola hardware generally.

## Safety

Both routes can crash, boot-loop the userspace, fill `/data`, or degrade radio features. DFRoot's exploit chain touches the kernel. Before anything:

1. Back up everything (photos, 2FA tokens, chats).
2. Remove the screen lock before switching into the container (OneOS documented a guest once taking over the lock-screen hardware slot; the guard exists in their app, but you are not using their app).
3. Use a phone you can afford to reset. Stock firmware restore for this model is documented in [docs/DEVICE-NOTES.md](docs/DEVICE-NOTES.md).
4. Never re-lock an unlocked bootloader that is running a GSI.

## Repo map

| Path | Contents |
| --- | --- |
| `docs/HOW-IT-WORKS.md` | How OneLineage/OneOS actually achieve "GSI running like the actual OS", and how DFRoot makes it possible on a locked Moto |
| `docs/ROUTE-B-CONTAINER.md` | The main guide: prerequisites, GSI download, porting OneLineage's scripts to `cancunn`, known Motorola-specific issues |
| `docs/ROUTE-A-FLASH-GSI.md` | Unlock the bootloader and flash the GSI for real (fastbootd, vbmeta, data wipe, restore) |
| `docs/DEVICE-NOTES.md` | `cancunn` facts: specs, partitions, firmware sources, unlock eligibility, links |
| `scripts/check-device.sh` | Read-only on-device probe: run it first, it prints everything this repo's guides depend on |

## Start here

```bash
adb push check-device.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/check-device.sh" > device-report.txt
```

Paste the output into an issue if you want help — it answers 90% of the questions.

## Credits

- [WeWaffles/OneLineage](https://github.com/WeWaffles/OneLineage) — the original container-GSI proof of concept this repo ports
- [fahadalijaved/OneOS](https://github.com/fahadalijaved/OneOS) — the productionized Samsung version; much of the behavioral knowledge here comes from their public docs
- [MisterZtr GSI](https://sourceforge.net/projects/misterztr-gsi/) ([GitHub](https://github.com/MisterZtr/LineageOS_gsi)) — the LineageOS GSI builds OneLineage consumes; the same builds are recommended here
- [diabl0w/DFRoot](https://github.com/diabl0w/DFRoot) (DirtyFrag, CVE-2026-43284) — locked-bootloader root this device already uses
- MysticGSI, TrebleDroid/phh — GSI ecosystem
- LineageOS, Android, Motorola and Samsung are trademarks of their respective owners. Not affiliated with any of them.
