#!/usr/bin/env bash
set -euo pipefail

ERASE_DTBO="${ERASE_DTBO:-no}"
FLASH_VBMETA="${FLASH_VBMETA:-no}"
FLASH_UEFI="${FLASH_UEFI:-no}"
ROOTFS_PARTITION="${ROOTFS_PARTITION:-userdata}"

if [[ ! -f pipa_rootfs.raw ]]; then
    shopt -s nullglob
    rootfs_parts=(pipa_rootfs.raw.part-*)
    shopt -u nullglob
    if [[ "${#rootfs_parts[@]}" -gt 0 ]]; then
        cat "${rootfs_parts[@]}" > pipa_rootfs.raw
    fi
fi

if [[ ! -f pipa_boot.raw && -f pipa_boot.raw.xz ]]; then
    xz -dk pipa_boot.raw.xz
fi
if [[ ! -f pipa_rootfs.raw && -f pipa_rootfs.raw.xz ]]; then
    xz -dk pipa_rootfs.raw.xz
fi

for file in pipa_esp.raw pipa_boot.raw pipa_rootfs.raw; do
    [[ -f "${file}" ]] || {
        echo "missing ${file}; extract all workflow artifacts together" >&2
        exit 1
    }
done

fastboot getvar product 2>&1 | grep -q pipa || {
    echo "connected fastboot device is not a Xiaomi Pad 6 (pipa)" >&2
    exit 1
}

cat <<EOF
Armada-pipa flash plan
======================
UEFI                 -> ${FLASH_UEFI}
ESP                  -> rawdump
boot                 -> cust
rootfs               -> ${ROOTFS_PARTITION}
erase dtbo           -> ${ERASE_DTBO}
flash vbmeta         -> ${FLASH_VBMETA}

This may overwrite Android userdata when ROOTFS_PARTITION=userdata.
EOF

read -r -p "Proceed? [y/N] " answer
[[ "${answer}" =~ ^[Yy]$ ]] || exit 0

if [[ "${ERASE_DTBO}" == yes ]]; then
    fastboot erase dtbo_ab
fi
if [[ "${FLASH_VBMETA}" == yes ]]; then
    fastboot flash vbmeta_ab vbmeta.img
fi
if [[ "${FLASH_UEFI}" == yes ]]; then
    fastboot flash boot_ab silicium.img
fi

fastboot flash rawdump pipa_esp.raw
fastboot flash cust pipa_boot.raw
fastboot flash "${ROOTFS_PARTITION}" pipa_rootfs.raw
fastboot reboot
