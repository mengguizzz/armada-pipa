# Xiaomi Pad 6 USB bring-up notes

This document records the boot path and fixes validated on a Xiaomi Pad 6
(`pipa`, SM8250-AC) using Mu-Silicium and an external USB SSD.

## Verified boot path

```text
Mu-Silicium UEFI
  -> USB ESP /EFI/BOOT/BOOTAA64.EFI
  -> GRUB
  -> Linux 7.1.4-pipa from the boot partition
  -> Btrfs OSTree root
  -> systemd
  -> SDDM
  -> Gamescope and Steam
```

The current bring-up uses the `7.1.4-pipa` kernel and module tree from the
working Ubuntu-pipa image. Armada's OSTree initramfs hooks and root filesystem
are retained.

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

### Touch orientation

The Novatek touch controller is connected over SPI. Gamescope only associates
I2C touch devices with the internal panel, so its automatic DSI rotation is not
applied to this device.

`99-pipa-touch-rotation.rules` applies the same 270-degree transform as
Gamescope's `right` panel orientation through
`LIBINPUT_CALIBRATION_MATRIX`.

### QCA6390 firmware during early boot

The image already contains the QCA6390 Wi-Fi and Bluetooth firmware, but the
devices probe during initramfs before the OSTree root is available. The custom
initramfs did not contain the firmware files, resulting in errors such as:

```text
Direct firmware load for ath11k/QCA6390/hw2.0/amss.bin failed with error -2
Direct firmware load for qca/htbtfw20.tlv failed with error -2
```

`30-pipa-network-firmware.conf` forces the required drivers into the initramfs
and installs the matching compressed firmware files.

## Remaining work

- Rebuild the initramfs and verify Wi-Fi and Bluetooth initialization.
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
