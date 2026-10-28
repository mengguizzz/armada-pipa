#!/usr/bin/env bash
set -euo pipefail

pipa_kernel="${PIPA_KERNEL_VERSION:-7.1.7-pipa}"
pipa_modules="/usr/lib/modules/${pipa_kernel}"

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
    swclock-offset-shutdown.service \
    qrtr-ns.service \
    pd-mapper.service \
    tqftpserv.service; do
    if [[ -f "/usr/lib/systemd/system/${unit}" ]]; then
        systemctl enable "${unit}" >/dev/null 2>&1 || true
    fi
done

if [[ -d "${pipa_modules}" ]]; then
    command -v dracut >/dev/null
    dracut \
        --force \
        --no-hostonly \
        --kver "${pipa_kernel}" \
        --add ostree \
        "${pipa_modules}/initramfs.img"
    chmod 0600 "${pipa_modules}/initramfs.img"
    test -s "${pipa_modules}/initramfs.img"
fi
