# Device notes — Moto G Power 5G (2024) "cancunn"

## Identity

| | |
| --- | --- |
| Model | XT2415 (variants XT2415-1/-3 retail, XT2415V Verizon) |
| Codename | `cancunn` |
| SoC | MediaTek Dimensity 7020 (2× Cortex-A78 + 6× Cortex-A55, Mali-G57 MC2) |
| RAM / Storage | 8 GB / 128 GB (microSD slot) |
| Display | 6.7" 120 Hz LCD, 1080×2400 |
| Battery | 5000 mAh |
| Ships with | Android 14, Motorola Hello UI (called "My UX" in some docs) |
| Updates | Android 15 rollout began January 2025 — check `ro.build.version.release` |
| Treble | yes — ARM64, A/B (virtual A/B), dynamic partitions (super) |

The device profile (ARM64 + A/B + dynamic partitions) is exactly what GSIs target, and DFRoot's exploit chain works on it — that combination is what makes both routes in this repo possible.

## Partitions (as observed on Android 14 firmware)

- Slots A and B for everything (`boot_a/b`, `vendor_boot_a/b`, `system_a/b` inside `super`, ...).
- **`boot.img`** is the Magisk target (the stock ROM for this device ships `boot.img` and `vendor_boot.img`; no `init_boot.img` on the Android 14 build — re-verify on newer firmware, Google moved Magisk to `init_boot` on many 2023+ devices).
- Dynamic partitions (`system`, `vendor`, `product`, ...) live in `super`; flashing any of them requires **fastbootd**, not bootloader-mode fastboot.

## Firmware and recovery sources

- **Rescue and Smart Assistant** (Motorola/Lenovo PC app): downloads and flashes full stock firmware for the exact IMEI — https://en-us.support.motorola.com/app/answers/detail/a_id/158726
- Lolinet mirrors host Moto firmware packs (look under `firmware/moto/` for `cancunn`): https://mirrors.lolinet.com/firmware/moto/
- Motorola upgrade schedule (which OS update this model gets): https://en-us.support.motorola.com/app/software-upgrade

## Bootloader unlock

- Official portal flow: Developer options → OEM unlocking → `fastboot oem get_unlock_data` → Motorola "Unlock your bootloader" support page → `fastboot oem unlock KEY`.
- **Not eligible through the official portal:** AT&T, Verizon, and TracFone (Straight Talk/Net10) branded units — this is a Motorola-wide policy, not specific to this model.
- XDA reference threads:
  - Rooting the Moto G Power (2024) (boot_a/boot_b Magisk flow, Android 14): https://xdaforums.com/t/moto-g-power-2024.4686132
  - XT2415V (Verizon) unlock effort: https://xdaforums.com/t/moto-g-power-xt-2415v-cancunn-g-power-2024-heres-your-bootloader-unlock.4803949

## Root (no unlock required)

- **DFRoot** (DirtyFrag, CVE-2026-43284): https://github.com/diabl0w/DFRoot — releases ship an APK; pair with any KernelSU-compatible manager (KernelSU, KernelSU-Next, diabl0w's KernelSU fork). Sets SELinux global permissive as part of the exploit chain; "Start on Boot" makes root survive reboots; "Disable KSU Modules" is the recovery switch if a module boot-loops you.
- Related/backup loaders: https://github.com/polygraphene/DFReroot , curated list: https://github.com/fynks/awesome-temporary-root

## GSI sources used by the reference projects

- MisterZtr GSI (LineageOS 23.2 / Android 16, arm64 ab, VANILLA/GAPPS, EXT4/EROFS): https://sourceforge.net/projects/misterztr-gsi/ — build scripts and patches: https://github.com/MisterZtr/LineageOS_gsi
- TrebleDroid / phh GSI ecosystem for reference on Treble letters and per-device quirks: https://github.com/TrebleDroid

## Reference projects

- OneLineage (the PoC this repo ports): https://github.com/WeWaffles/OneLineage — release APK: https://github.com/WeWaffles/OneLineage/releases/tag/v1.0.0
- OneOS (hardened Samsung-only successor): https://github.com/fahadalijaved/OneOS — its `docs/` directory is the best public write-up of container-GSI failure modes

## Open questions on this device (help by testing)

1. No published GSI result (flashed or container) for `cancunn` was found at writing time — first confirmations welcome, either route.
2. Exact Motorola IMS daemon set to gate/keep-alive in the container route (check-device.sh prints candidates).
3. Android 15 host vs Android 16 GSI API gap (see Route B, section 2c) — if it blocks, the Android 15 branch of MisterZtr's GSI is the fallback to try first.
