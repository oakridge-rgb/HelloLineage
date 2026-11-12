# Route A — Flash the GSI for real (unlock bootloader, fastbootd)

If you want LineageOS to *be* the actual OS — normal boot, working calls/SMS, no container overhead — the GSI has to be written to the system partition. That requires an **unlocked bootloader**, which DFRoot deliberately avoids using. Decide with eyes open:

- Unlocking wipes the phone (twice, effectively: `oem unlock` and the post-flash format).
- It voids the warranty and trips permanent unlock flags.
- Carrier-branded units (AT&T, Verizon, TracFone/Straight Talk/Net10) are **not eligible** through Motorola's official portal; retail/factory-unlocked XT2415 units are. There is an XDA thread working on XT2415V unlock paths (see DEVICE-NOTES).
- You can never re-lock this bootloader while a GSI is on it.

Everything below is the standard Motorola GSI flow adapted to `cancunn`.

## 1. Backup, then set up the PC

- Full backup (this erases everything).
- Install [platform-tools](https://developer.android.com/tools/releases/platform-tools) (fastboot + adb), and Motorola USB drivers on Windows.
- Install **Rescue and Smart Assistant** (Motorola/Lenovo) — your insurance policy; it can re-flash stock firmware unattended (link in DEVICE-NOTES).
- Have the stock firmware for XT2415 on disk (Rescue tool download, or the lolinet mirrors — see DEVICE-NOTES).

## 2. Unlock the bootloader

1. Phone: Settings → About phone → tap Build number 7× → Developer options → enable **OEM unlocking** and **USB debugging**.
2. Boot bootloader: power off, hold **Vol Down + Power**.
3. `fastboot oem get_unlock_data` → concatenate the returned chunks into one line.
4. Submit that string at Motorola's unlock portal (Motorola support → "Unlock your bootloader"; the page issues a unique key per device).
5. `fastboot oem unlock YOUR_KEY` — confirm on-device with Vol Up. Device wipes. Repeat the command if the firmware asks for it twice.

If the portal says "device does not qualify", you are probably carrier-locked (see above) — Route A is closed until that is resolved; Route B does not care.

## 3. Flash the GSI (fastbootd, not bootloader-fastboot)

Dynamic-partition devices must be flashed from **fastbootd** (the userspace fastboot in recovery), otherwise `flash system` fails with a partition-table error.

1. Get a GSI: [MisterZtr LineageOS 23.2](https://sourceforge.net/projects/misterztr-gsi/) — **arm64, A/B** build (VANILLA or GAPPS, EXT4 or EROFS both fine when flashed). Extract `system.img` from the `.7z`.
2. From the stock firmware zip, keep `vbmeta.img` handy.
3. Boot bootloader, then:
   ```bash
   fastboot reboot fastboot        # boots into fastbootd
   fastboot flash vbmeta vbmeta.img --disable-verity --disable-verification
   fastboot delete-logical-partition product_a
   fastboot delete-logical-partition product_b
   fastboot flash system system.img
   fastboot -w                     # format userdata (required on first GSI boot)
   fastboot reboot
   ```
4. First boot sits on the Lineage boot animation for several minutes (GSI first-boot dexopt). Give it 10–15 minutes before panicking; a second forced reboot sometimes shakes it loose.

Notes:

- `delete-logical-partition product` frees the space the GSI needs inside the dynamic super partition; the GSI provides its own product. If boot fails with the GSI, flashing the stock firmware back (step 5) restores everything including `product`.
- Slots: this device is A/B; fastbootd routes `flash system` to the active slot, which is what you want.
- If the GSI boot-loops: try the other Treble lettering (`bvS` ↔ `bvNE`), or a GSI built for a lower API level. Treble letter mismatches are the #1 GSI boot failure and cost nothing to swap.

## 4. First-boot fixes and re-root

- In Settings → Treble (phh) settings: enable the MediaTek/MTK quirks if audio or RIL misbehaves; set "Force known working audio policy" variants as needed.
- OTA updates from Motorola will not apply over a GSI — disable auto-updates to avoid failed-update loops.
- Banking/DRM apps: Widevine drops to L3 on a GSI; plan accordingly.
- Re-root if wanted: take `boot.img` (or `init_boot.img` on firmware generations that moved Magisk there — the XT2415 Android 14 firmware ships `boot.img` + `vendor_boot.img` and no `init_boot.img`; verify against your exact firmware file list), patch it with Magisk, and `fastboot flash boot_a boot_patched.img` + same for `boot_b` (partition names as fastbootd reports them). DFRoot is not needed anymore once the bootloader is unlocked, but its manager can still be used.

## 5. Restore stock firmware

- Easiest: **Rescue and Smart Assistant** → "Rescue" → it downloads and flashes the full stock image for your IMEI/model, then reboots to factory-fresh Hello UI.
- Manual: extract the stock zip and flash every image per its `flashfile.xml` service order with fastbootd, then `fastboot -w`.
- The bootloader stays unlockable/unlocked; only re-lock it **after** full stock is restored, if ever, with `fastboot oem lock` — and only with stock on both slots, never with a GSI.
