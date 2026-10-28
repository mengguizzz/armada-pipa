# Xiaomi Pad 6 USB bring-up notes

This document records the boot path and fixes validated on a Xiaomi Pad 6
(`pipa`, SM8250-AC) using Mu-Silicium and an external USB SSD.

## Verified boot path

```text
Mu-Silicium UEFI
  -> USB ESP /EFI/BOOT/BOOTAA64.EFI
  -> GRUB
  -> upstream Linux 7.1.7-pipa from the boot partition
  -> Btrfs OSTree root
  -> systemd
  -> SDDM
  -> Gamescope and Steam
```

The build pins the upstream `linux-image-pipa`, `linux-modules-pipa`, and
matching Pipa DTB packages. Dracut generates the Pipa initramfs inside the
container so the Image, modules, firmware, and device tree always come from the
same kernel release. Armada's OSTree hooks and root filesystem are retained.

## Required partition UUIDs

Armada's mount units currently expect:

| Partition | UUID |
| --- | --- |
| boot (ext4) | `c1ff985b-b09f-4c96-abec-795260e5ee48` |
| ESP (FAT) | `34A8-528F` |
| root (Btrfs) | `e54a4625-b3be-4780-a4f3-2d6cf1909378` |

Do not leave a temporary service mounted at the final `/boot` path. It prevents
systemd from mounting the real boot filesystem and sends the image to
`emergency.target`.

## Fixes carried by this repository

### Boot-time fake suspend

Armada replaces suspend with `fake-suspend` on pipa. A power/lid event received
while the graphical session is still starting can turn off the backlight and
leave a black screen even though boot and Steam continue in the background.

The local `fake-suspend` override ignores suspend requests until a Gamescope or
Wayland session socket exists.

### Protective-case Hall sensor

The Pad 6 protective folio can trigger the generic lid switch and put the
system to sleep. This is not a useful clamshell signal on a standalone tablet.
The image disables lid events both in `systemd-logind` and in Armada's
`powerbuttond` through `ARMADA_DISABLE_LID=1`. Power-button sleep remains
available.

### Touch orientation

The Novatek touch controller is connected over SPI. Gamescope only associates
I2C touch devices with the internal panel, so its automatic DSI rotation is not
applied to this device.

`99-pipa-touch-rotation.rules` applies the same 270-degree transform as
Gamescope's `right` panel orientation through
`LIBINPUT_CALIBRATION_MATRIX`.

### Qualcomm firmware during early boot

The image already contains the QCA6390 Wi-Fi, Bluetooth, ADSP, SLPI, CDSP, and
Venus firmware, but the devices probe during initramfs before the OSTree root is
available. The custom initramfs did not contain the firmware files, resulting
in errors such as:

```text
Direct firmware load for ath11k/QCA6390/hw2.0/amss.bin failed with error -2
Direct firmware load for qca/htbtfw20.tlv failed with error -2
Direct firmware load for qcom/sm8250/xiaomi/pipa/adsp.mbn failed with error -2
```

`30-pipa-firmware.conf` is the single initramfs policy for all early-probing
pipa hardware. It installs Wi-Fi, Bluetooth, DSP, sensor, media, and GPU firmware
together so new subsystems do not need separate fixes.

### Root filesystem size

The exported root filesystem is intentionally small and the GPT root partition
is larger. If the Btrfs filesystem was not grown after flashing, resize it
online:

```bash
sudo btrfs filesystem resize max /
```

## Resource reporting

The device reserves memory for firmware, remote processors, display splash,
ramoops, and CMA. On an 8 GiB Pad 6 the kernel reports approximately
`7.5 GiB available / 7.68 GiB total`, so a 7 GiB userspace reading is expected.

Adreno 650 uses shared system memory. A Steam or Mesa value around 6 GiB is a
UMA aperture/reporting value, not a second 6 GiB dedicated VRAM allocation.

The pipa kernel boots all eight CPUs. Steam's hardware page may show an empty
or generic CPU name on ARM64, but that does not indicate that CPU detection or
SMP is missing.

## Fedora user-space baseline

The Fedora `pipa-sound-conf` package provides the current UCM and WirePlumber
configuration. Its latest package split uses `alsa-ucm-conf-sm8250` for UCM;
this repository vendors the corresponding configuration files so the image
does not depend on cross-distribution RPM compatibility.

The Fedora `pipa-metapkg` is a dependency bundle rather than a driver. Relevant
components are `kernel-pipa`, `xiaomi-pipa-firmware`, `pipa-dracut`,
`pipa-sound-conf`, `pipa-sensor-restart`, and the matching kernel modules.

The build uses the Pocketblue SM8250 and common COPR repositories for
hardware-specific Fedora packages. Armada's Steam, Gamescope, OSTree, HUD, and
device integration remain local. The boot kernel is the upstream Pipa kernel,
not Armada's generic handheld kernel.

## Image size

Starting from the full Armada image is intentionally temporary. The build
prunes documentation, SystemTap/SGML data, and firmware for unrelated SoCs while
retaining Qualcomm, QCA, Atheros, and Novatek firmware. Further large reductions
would require removing optional applications, FEX's x86 rootfs, or the Steam
runtime and should be explicit product decisions.

The exported raw filesystem is tried at 15, 16, 17, then 18 GiB. A raw sparse
image is not a useful download-size indicator because archive uploads that do
not preserve sparse ranges store zero blocks. Rootfs artifacts therefore use
compression, while the extracted files remain compatible with the existing
flashing script.

## Remaining work

- Rebuild the initramfs and verify ADSP-backed audio initialization.
- Match all kernel modules to the kernel that is actually booted. Do not mix
  modules from different kernel releases.
- Create `/boot/loader` metadata expected by rpm-ostree or adapt the OSTree boot
  integration.
- Evaluate the Fedora pipa stack (`linux-firmware`, `pipa-metapkg`, and the
  Pocketblue kernel packages) as the next kernel upgrade path.
- Add audio, sensors, camera, charging, and suspend support incrementally.

## Fedora reference

The Fedora builder is useful as a source of packaging and hardware enablement,
not as a binary drop-in replacement. It uses Fedora's `linux-firmware`,
`pipa-metapkg`, and the Pocketblue SM8250 COPR repository, with a matching
kernel and userspace.

- <https://github.com/rr1111/pipa-fedora-builder-43>
- <https://github.com/pipa-mainline/linux>
- <https://github.com/pocketblue>
