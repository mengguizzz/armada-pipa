#!/usr/bin/env bash
set -euo pipefail

RAW="${1:?usage: export-pipa-images.sh <disk.raw> <output-dir> <grubaa64.efi> <pipa.dtb>}"
OUT="${2:?usage: export-pipa-images.sh <disk.raw> <output-dir> <grubaa64.efi> <pipa.dtb>}"
GRUBAA64_EFI="${3:?usage: export-pipa-images.sh <disk.raw> <output-dir> <grubaa64.efi> <pipa.dtb>}"
PIPA_DTB="${4:?usage: export-pipa-images.sh <disk.raw> <output-dir> <grubaa64.efi> <pipa.dtb>}"
ROOTFS_SIZE="${ROOTFS_SIZE:-15G}"

[[ -f "${RAW}" ]] || {
    echo "raw disk not found: ${RAW}" >&2
    exit 1
}
[[ -f "${GRUBAA64_EFI}" ]] || {
    echo "GRUB EFI binary not found: ${GRUBAA64_EFI}" >&2
    exit 1
}
[[ -f "${PIPA_DTB}" ]] || {
    echo "pipa DTB not found: ${PIPA_DTB}" >&2
    exit 1
}

mkdir -p "${OUT}" "${OUT}/work"
WORK="$(mktemp -d "${OUT}/work/mnt.XXXXXX")"
LOOP=""
L1=""
L2=""
LROOT=""

cleanup() {
    sudo umount "${WORK}/src2" 2>/dev/null || true
    sudo umount "${WORK}/boot" 2>/dev/null || true
    sudo umount "${WORK}/esp" 2>/dev/null || true
    sudo umount "${WORK}/rootfs" 2>/dev/null || true
    [[ -z "${LOOP}" ]] || sudo losetup -d "${LOOP}" 2>/dev/null || true
    [[ -z "${L1}" ]] || sudo losetup -d "${L1}" 2>/dev/null || true
    [[ -z "${L2}" ]] || sudo losetup -d "${L2}" 2>/dev/null || true
    [[ -z "${LROOT}" ]] || sudo losetup -d "${LROOT}" 2>/dev/null || true
    rm -rf "${WORK}"
}
trap cleanup EXIT

LOOP="$(sudo losetup --find --show --partscan "${RAW}")"
sudo udevadm settle || true
sleep 2

mapfile -t PARTS < <(
    sudo sfdisk -J "${LOOP}" |
        jq -r '.partitiontable.partitions[] | [.start, .size] | @tsv'
)

if [[ "${#PARTS[@]}" -ne 3 ]]; then
    sudo sfdisk -l "${LOOP}" >&2
    echo "expected exactly 3 partitions, found ${#PARTS[@]}" >&2
    exit 1
fi

P1="${LOOP}p1"
P2="${LOOP}p2"
P3="${LOOP}p3"

[[ "$(sudo blkid -s TYPE -o value "${P1}")" == vfat ]] || {
    echo "${P1} is not vfat" >&2
    exit 1
}
[[ "$(sudo blkid -s TYPE -o value "${P2}")" == ext4 ]] || {
    echo "${P2} is not ext4" >&2
    exit 1
}
[[ "$(sudo blkid -s TYPE -o value "${P3}")" == btrfs ]] || {
    echo "${P3} is not btrfs" >&2
    exit 1
}

mkdir -p "${WORK}/src2" "${WORK}/boot" "${WORK}/esp" "${WORK}/rootfs"

P2_LABEL="$(sudo blkid -s LABEL -o value "${P2}")"
P2_UUID="$(sudo blkid -s UUID -o value "${P2}")"

sudo mount -o ro "${P2}" "${WORK}/src2"

DEPLOY="$(sudo find "${WORK}/src2/ostree" -mindepth 1 -maxdepth 1 \
    -type d -name 'default-*' -printf '%f\n' | head -n1)"
[[ -n "${DEPLOY}" ]] || {
    echo "unable to locate OSTree deployment on ${P2}" >&2
    sudo find "${WORK}/src2" -maxdepth 3 -type d >&2
    exit 1
}

BOOTDIR="${WORK}/src2/ostree/${DEPLOY}"
KERNEL="$(sudo find "${BOOTDIR}" -maxdepth 1 -type f \
    -name 'vmlinuz-*' | head -n1)"
INITRAMFS="$(sudo find "${BOOTDIR}" -maxdepth 1 -type f \
    -name 'initramfs-*.img' | head -n1)"
BLS="$(sudo find "${WORK}/src2" -path '*/loader*/entries/*.conf' \
    -type f | head -n1)"

for path in "${KERNEL}" "${INITRAMFS}" "${BLS}"; do
    [[ -f "${path}" ]] || {
        echo "missing required Armada boot artifact: ${path}" >&2
        exit 1
    }
done

KARGS="$(sudo sed -n 's/^options //p' "${BLS}" | head -n1)"
[[ "${KARGS}" == *ostree=* ]] || {
    echo "Armada BLS entry has no ostree= argument: ${BLS}" >&2
    exit 1
}
KARGS="${KARGS} boot=LABEL=pipa-boot clk_ignore_unused pd_ignore_unused"

truncate -s 1G "${OUT}/pipa_boot.raw"
mkfs.ext4 -F -q -L pipa-boot -U "${P2_UUID}" \
    -O ^64bit,^metadata_csum,^metadata_csum_seed,^orphan_file \
    "${OUT}/pipa_boot.raw"
L2="$(sudo losetup --find --show "${OUT}/pipa_boot.raw")"
sudo mount "${L2}" "${WORK}/boot"
sudo install -Dm0644 "${KERNEL}" "${WORK}/boot/Image"
sudo install -Dm0644 "${INITRAMFS}" "${WORK}/boot/initramfs.img"
sudo install -Dm0644 "${PIPA_DTB}" "${WORK}/boot/sm8250-xiaomi-pipa.dtb"
sudo sync
sudo umount "${WORK}/src2" "${WORK}/boot"
sudo losetup -d "${L2}"
L2=""

truncate -s 128M "${OUT}/pipa_esp.raw"
mkfs.vfat -F 32 -n PIPAESP "${OUT}/pipa_esp.raw" >/dev/null
L1="$(sudo losetup --find --show "${OUT}/pipa_esp.raw")"
sudo mount "${L1}" "${WORK}/esp"
sudo mkdir -p "${WORK}/esp/EFI/BOOT"
sudo install -Dm0644 "${GRUBAA64_EFI}" "${WORK}/esp/EFI/BOOT/BOOTAA64.EFI"
sudo tee "${WORK}/esp/EFI/BOOT/grub.cfg" >/dev/null <<EOF
set default=0
set timeout=5
search --no-floppy --label pipa-boot --set=boot
if [ -z "\${boot}" ]; then
    echo "pipa-boot partition not found"
    sleep 10
fi
menuentry "Armada (Xiaomi Pad 6)" {
    linux (\$boot)/Image --- ${KARGS}
    initrd (\$boot)/initramfs.img
    devicetree (\$boot)/sm8250-xiaomi-pipa.dtb
}
menuentry "Armada recovery shell" {
    linux (\$boot)/Image --- ${KARGS} systemd.unit=multi-user.target
    initrd (\$boot)/initramfs.img
    devicetree (\$boot)/sm8250-xiaomi-pipa.dtb
}
EOF
sudo sync
sudo umount "${WORK}/esp"
sudo losetup -d "${L1}"
L1=""

sudo dd if="${P3}" of="${OUT}/pipa_rootfs.raw" bs=16M conv=sparse status=progress
sudo sync

# BIB reserves enough free space for a staged bootc upgrade. The installed tree
# is substantially smaller, so shrink the exported filesystem before download.
# The target partition is larger and bootc growpart expands it on first boot.
LROOT="$(sudo losetup --find --show "${OUT}/pipa_rootfs.raw")"
sudo mount "${LROOT}" "${WORK}/rootfs"
{
    echo "before:"
    sudo btrfs filesystem usage -h "${WORK}/rootfs"
    echo
    echo "top-level usage:"
    sudo du -x -h --max-depth=1 "${WORK}/rootfs/root" | sort -h
} > "${OUT}/ROOTFS-USAGE.txt"
sudo btrfs filesystem resize "${ROOTFS_SIZE}" "${WORK}/rootfs"
{
    echo
    echo "after resize to ${ROOTFS_SIZE}:"
    sudo btrfs filesystem usage -h "${WORK}/rootfs"
} >> "${OUT}/ROOTFS-USAGE.txt"
sudo sync
sudo umount "${WORK}/rootfs"
sudo losetup -d "${LROOT}"
LROOT=""
truncate -s "${ROOTFS_SIZE}" "${OUT}/pipa_rootfs.raw"

find "${OUT}" -maxdepth 1 -type f -printf '%f %s bytes\n' |
    sort > "${OUT}/PARTITIONS.txt"

{
    echo "source=${RAW}"
    echo "boot_source=${P2} label=${P2_LABEL:-} uuid=${P2_UUID}"
    echo "root_source=${P3} uuid=$(sudo blkid -s UUID -o value "${P3}")"
    echo "rootfs_size=${ROOTFS_SIZE}"
    echo "kernel=${KERNEL}"
    echo "initramfs=${INITRAMFS}"
    echo "dtb=${PIPA_DTB}"
    echo "kargs=${KARGS}"
} > "${OUT}/PARTITION-UUIDS.txt"
