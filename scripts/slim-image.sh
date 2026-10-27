#!/bin/bash
set -euo pipefail

# Documentation and developer data are not used by the runtime image.
rm -rf \
    /usr/share/doc \
    /usr/share/gtk-doc \
    /usr/share/help \
    /usr/share/info \
    /usr/share/man \
    /usr/share/sgml \
    /usr/share/systemtap

# Keep firmware relevant to the SM8250 Xiaomi Pad 6. This removes large
# unrelated GPU, Wi-Fi, NIC, and vendor firmware sets from linux-firmware.
firmware_root=/usr/lib/firmware
if [[ -d "${firmware_root}" ]]; then
    for path in "${firmware_root}"/*; do
        [[ -e "${path}" || -L "${path}" ]] || continue
        name="$(basename "${path}")"
        case "${name}" in
            ath10k|ath11k|novatek|qca|qcom|regulatory.db*) ;;
            *) rm -rf -- "${path}" ;;
        esac
    done
fi
