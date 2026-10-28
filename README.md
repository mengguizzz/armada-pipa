# Armada for Xiaomi Pad 6 (pipa)

Experimental Armada-derived image for the Xiaomi Pad 6. The goal is to bring
Armada's ARM64 Steam, FEX, Proton, gamescope, and KDE stack to pipa while using
the device support already proven by the pipa Linux port.

This repository does **not** rebuild all of Armada. GitHub Actions starts from
the published `ghcr.io/armada-os/armada:testing` image and layers on:

- upstream pipa `7.1.7` Image, modules, initramfs, and matching DTB
- Xiaomi Pad 6 firmware and Qualcomm firmware service configuration
- pipa audio, boot MAC, and clock support
- an Armada device profile for the Xiaomi Pad 6

The output is split into the same fastboot targets used by the other pipa
Linux ports:

| Output | fastboot target |
| --- | --- |
| `pipa_esp.raw` | `rawdump` |
| `pipa_boot.raw` | `cust` |
| `pipa_rootfs.raw.part-*` | `userdata` or a dedicated `linux` partition |

Mu-Silicium remains the boot firmware. The build workflow does not flash or
modify a device.

## Status

This is a bring-up prototype. USB boot, display, touch, Steam startup, Wi-Fi,
Bluetooth, and root filesystem growth are validated on hardware. Audio, sensors,
camera, suspend, and OTA-safe kernel replacement still need device testing.

See [docs/usb-bringup.md](docs/usb-bringup.md) for the validated USB boot path,
partition UUIDs, touch rotation, fake-suspend handling, and QCA6390 firmware
requirements.

## Build

Run the **Build pipa images** workflow manually from the Actions tab. It runs on
GitHub's native ARM64 runner and uploads compressed image artifacts.

Local PowerShell/Windows does not need Podman or an ARM64 compiler.

## Flashing

Download and extract the workflow artifacts into one directory, then inspect
`BUILDINFO.txt` and `PARTITIONS.txt`. With the tablet in fastboot mode:

```bash
chmod +x flash-pipa.sh
./flash-pipa.sh
```

The script does not flash Mu-Silicium by default. Set `FLASH_UEFI=yes` only if
the existing UEFI installation needs to be replaced.

The rootfs is split into 1.9 GiB parts and compressed as GitHub artifacts. The
flash script concatenates the extracted parts automatically before invoking
fastboot.

## Upstream

- [Armada](https://github.com/armada-os/armada)
- [pipa Linux](https://github.com/PAD6-DEV/linux-7.xx)
- [pipa packages](https://github.com/thespider2/pipa-pkgs)
- [Mu-Silicium](https://github.com/onesaladleaf/Mu-Silicium)
