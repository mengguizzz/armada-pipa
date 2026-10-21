#!/usr/bin/env bash
set -euo pipefail

KVER=7.1.7-pipa
MODDIR="/usr/lib/modules/${KVER}"

[[ -d "${MODDIR}" ]] || {
    echo "missing pipa modules at ${MODDIR}" >&2
    exit 1
}
[[ -f /boot/Image ]] || {
    echo "missing pipa kernel image at /boot/Image" >&2
    exit 1
}
[[ -f /boot/dtbs/qcom/sm8250-xiaomi-pipa.dtb ]] || {
    echo "missing pipa DTB" >&2
    exit 1
}

# bootc requires one kernel and its matching modules.
find /usr/lib/modules -mindepth 1 -maxdepth 1 \
    ! -name "${KVER}" -exec rm -rf {} +
rm -f "${MODDIR}/build" "${MODDIR}/source"

install -Dm0644 /boot/Image "${MODDIR}/vmlinuz"
install -Dm0644 "/boot/config-${KVER}" "${MODDIR}/config"
install -Dm0644 "/boot/System.map-${KVER}" "${MODDIR}/System.map"
install -Dm0644 /boot/dtbs/qcom/sm8250-xiaomi-pipa.dtb \
    "${MODDIR}/dtb/qcom/sm8250-xiaomi-pipa.dtb"

depmod -a "${KVER}" -b /

# The pipa package supplies firmware and the keyboard-cover driver early enough
# for initramfs. Armada's own modules provide the splash and OSTree fallback.
dracut \
    --force \
    --no-hostonly \
    --reproducible \
    --kver "${KVER}" \
    --add ostree \
    --add armada-splash \
    --add armada-ostree-fallback \
    "${MODDIR}/initramfs.img" \
    "${KVER}"

touch /usr/lib/armada/supported-dtbs
if ! grep -qx 'sm8250-xiaomi-pipa' /usr/lib/armada/supported-dtbs; then
    printf '%s\n' 'sm8250-xiaomi-pipa' >> /usr/lib/armada/supported-dtbs
fi

if ! grep -q '"Xiaomi Pad 6") profile=xiaomi-pipa' \
        /usr/libexec/armada/device-env; then
    sed -i \
        '/"Retroid Pocket 5") profile=retroid-pocket-5 ;;/i\    "Xiaomi Pad 6") profile=xiaomi-pipa ;;' \
        /usr/libexec/armada/device-env
fi

for unit in \
    pipa-audio-init.service \
    bootmac-bluetooth.service \
    swclock-offset-boot.service \
    swclock-offset-shutdown.service; do
    if [[ -f "/usr/lib/systemd/system/${unit}" ]]; then
        systemctl enable "${unit}" >/dev/null 2>&1 || true
    fi
done

rm -rf /boot/dtbs /boot/Image /boot/System.map-* /boot/config-*
