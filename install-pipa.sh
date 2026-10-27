#!/usr/bin/env bash
set -euo pipefail

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
