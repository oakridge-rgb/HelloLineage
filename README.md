# HelloLineage

**Get LineageOS running on a Motorola phone — replacing Hello UI.**

Inspired by [WeWaffles/OneLineage](https://github.com/WeWaffles/OneLineage) (the proof-of-concept that hot-switches a Samsung phone into a LineageOS container). This repo is the Motorola-side guide: what works today, what's experimental, and what a Hello UI port of OneLineage would take.

> **First, a mix-up worth clearing:** Motorola phones don't run One UI — that's Samsung's skin. Motorola's skin is **Hello UI** (formerly My UX). Hence the name: Hello UI -> Lineage. OneLineage as shipped only targets rooted Samsung phones on One UI 8.5.

---

## The three routes at a glance

| | Route | What you do | Difficulty | Calls / SMS | Reversible |
|---|---|---|---|---|---|
| 1 | **Official LineageOS build** *(recommended)* | Unlock bootloader, flash the official build made for your exact model | Medium | Yes, fully | Yes — flash stock firmware back |
| 2 | **LineageOS GSI (Treble)** | Unlock bootloader, flash a generic system image | Medium-hard | Mostly (vendor quirks) | Yes |
| 3 | **OneLineage-style container** *(research)* | Root + run LineageOS in a pivot container next to Hello UI — nothing flashed | Very hard | **No** (no IMS in the guest) | Yes — it never touches partitions |

---

## Route 1 — Official LineageOS build (recommended)

This is the proven, full-replacement path. LineageOS officially supports a long list of Motorola devices.

### Step 1 — Find your device codename

Look up your exact model (the `XT…` number is in Settings > About phone, and printed on the box). Then check the official device list: **https://wiki.lineageos.org/devices/**

Popular Motorola devices with official LineageOS builds (check the wiki for the current build status of each):

| Device | Codename |
|---|---|
| edge 40 / edge 40 pro (moto X40) | lyriq / rtwo |
| edge 30 ultra / fusion / neo | eqs / tundra / miami |
| edge 2021 / edge 20 / edge 2024 | berlna / berlin / avatrn |
| edge s (moto g100) | nio |
| moto g84 5G / g82 5G | bangkk / rhodep |
| moto g stylus 5G (2022) / (2023) | milanf / genevn |
| moto g stylus 5G | denver |
| moto g 5G (2024) / moto g 5G | fogo / kiev |
| moto g 5G plus | nairo |
| moto g7 / g7 play / g7 plus / g7 power | river / channel / lake / ocean |
| moto g32 / g42 / g52 | devon / hawao / rhode |
| moto g10 / g30 | capri / caprip |
| moto g9 play / g9 power | guamp / cebu |
| moto g200 5G (Edge S30) | xpeng |
| moto g4 / g5 / g5s | athene / cedric / montana |
| moto e7 plus | guam |
| moto x4 | payton |
| moto z2 force / z3 | nash / messi |
| one vision / one action / one zoom | kane / troika / parker |
| ThinkPhone | bronco |
| defy (2021) | bathena |

> The LineageOS wiki warns: devices not listed are **not supported**, builds for other devices **cannot be used**, and "nearly identical" is **not** sufficient. The 2024 model of a phone is not the 2023 model.

### Step 2 — Unlock the bootloader

Motorola provides an official unlock portal:

1. Enable **Developer options** (tap Build number 7x) and turn on **OEM unlocking** + **USB debugging**.
2. Boot to fastboot: power off, hold **Vol Down** + power, plug into a PC.
3. `fastboot oem get_unlock_data` — send the printed string to Motorola's portal: **https://motorola-global-portal.custhelp.com/app/standalone/bootloader**
4. Motorola emails you an unlock key, then: `fastboot oem unlock UNIQUE_KEY`

**Warnings:** unlocking **wipes all user data**, and it affects warranty. Some carrier-locked models (historically Verizon) can't be unlocked at all.

### Step 3 — Install LineageOS

Follow your device's own page on the LineageOS wiki — it has the exact fastboot/recovery commands for your codename:

1. Flash the LineageOS recovery image(s) (boot / vendor_boot / recovery, per your device page).
2. Sideload the LineageOS zip: recovery > **Apply update** > **Apply from ADB** > `adb sideload lineage-*.zip`.
3. (Optional) Sideload **MindTheGapps** right after, if you want the Play Store.
4. Format data/factory reset when the wiki says so, then reboot.

Full guide format: https://wiki.lineageos.org/devices/ -> your device -> "Installation".

### Step 4 — Rollback (if you ever want Hello UI back)

Flash the stock Motorola firmware for your exact model (Motorola's rescue/agent tool, or the full factory images via fastboot). Firmware is per-model — never flash another model's image.

---

## Route 2 — LineageOS GSI (if your model has no official build)

A GSI (Generic System Image) is a Treble system image that runs on any compliant device. This is the closest thing to "OneLineage's LineageOS 23.2 GSI" but installed permanently.

1. **Unlock the bootloader** (same as Route 1 step 2).
2. **Check Treble support**: install "Treble Info" from Play Store — note your architecture (arm64) and partition style (A/B or A-only).
3. **Get a LineageOS-based GSI** from a trusted Treble builder — see [TrebleDroid](https://github.com/TrebleDroid) (the maintained phh-Treble lineage; phh's original project lives at [phhusson/treble_experimentations](https://github.com/phhusson/treble_experimentations)). Pick the image type Treble Info recommends (arm64-ab etc.), vanilla or gapps.
4. Flash (typical pattern — your device's XDA thread has the exact commands):

```bash
fastboot flash vbmeta vbmeta.img --disable-verity --disable-verification
fastboot flash system arm64-ab-lineage.img
fastboot -w        # wipe data
fastboot reboot
```

5. **Motorola quirks:** camera, fingerprint, NFC and VoLTE may be broken depending on the vendor blob match. Your device's XDA forum thread is the place to find which GSI variant works best on your exact model.

---

## Route 3 — The OneLineage way on Motorola (experimental research)

What [OneLineage](https://github.com/WeWaffles/OneLineage) does on Samsung: it stages a LineageOS 23.2 GSI under `/data/local/tmp`, then **pivot_root's into it as a userspace container with its own zygote and system_server** — no reflashing, no second partition, and it can hand the screen back to One UI. Root required; nothing is permanently modified.

Why it doesn't work on Motorola as-is: its patches are built against **One UI 8.5's** framework files. The good news is that the hard part on Samsung (root) is *easier* on Motorola, because an unlocked Motorola bootloader allows clean permanent Magisk root — no temp-root tricks.

An honest look at what a Hello UI port needs is in **[PORTING.md](PORTING.md)**.

Even on its home turf (S26 Ultra / S26 / A25, One UI 8.5) OneLineage is a proof of concept: voice calls don't work in the guest (no IMS stack), the session can get thrown back to the host after minutes, and developer options crash. The upstream author says support for other devices is extremely limited.

---

## Warnings (read before any route)

- **Unlocking wipes your phone.** Back up everything first.
- **Warranty:** an unlocked bootloader voids Motorola warranty coverage.
- **Model numbers matter.** A build for `moto g 5G (kiev)` must never go on `moto g 5G plus (nairo)`. Check the XT number twice.
- **Anti-rollback:** don't downgrade firmware versions below what your device shipped.
- **Banking/DRM apps** may refuse to run on unlocked/unrooted-flagged devices.
- Route 3 never flashes anything, but a container can still soft-hang the UI until reboot.

---

## Credits

- [WeWaffles/OneLineage](https://github.com/WeWaffles/OneLineage) — the container hot-switch concept and the inspiration for this repo.
- [LineageOS](https://wiki.lineageos.org/devices/) — official builds and install guides.
- [TrebleDroid](https://github.com/TrebleDroid) / [phh-Treble](https://github.com/phhusson/treble_experimentations) — the GSI ecosystem.
- Motorola's official bootloader unlock portal: https://motorola-global-portal.custhelp.com/app/standalone/bootloader
