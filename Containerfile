ARG BASE_IMAGE=ghcr.io/armada-os/armada:testing

FROM debian:13-slim AS pipa-payload

ARG PIPA_REPO_URL=https://thespider2.github.io/pipa-pkgs/repo/ubuntu

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /payload

RUN set -eux; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/linux-image-pipa_7.1.7-4pipa1_arm64.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/linux-modules-pipa_7.1.7-4pipa1_arm64.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/xiaomi-pipa-firmware_1.1-4pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/pipa-dracut_1.1-7pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/pipa-sound-conf_1.4-12pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/bootmac_0.6.0-1pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/swclock-offset_0.3.0-1pipa1_all.deb"; \
    printf '%s  %s\n' \
      'fedb8f120dbdb43ff2074d9732cddf5d79f238761c8f15e28954c474830c45e9' 'linux-image-pipa_7.1.7-4pipa1_arm64.deb' \
      'f0271d76444060749262f9844ea19ac6d98f7db1e76e3b1304bad28c31b6ec00' 'linux-modules-pipa_7.1.7-4pipa1_arm64.deb' \
      'c5f4ade9f0ce83cb014839faffd911d7958d6d5dbc3411b7fd4361129c5d0718' 'xiaomi-pipa-firmware_1.1-4pipa1_all.deb' \
      '725e7b7509dedbbf853af0d24ba0dc60e1e8f006f20a527e7a77e135d61cfb39' 'pipa-dracut_1.1-7pipa1_all.deb' \
      '48121bc2815f00c6fb6f25d1f42899338b240a8511b6ca8accd3a7795ffc9e72' 'pipa-sound-conf_1.4-12pipa1_all.deb' \
      '12e119491e8678223ac2d752b6877ee2ec623c21294aeec64fcc77d63dfa8350' 'bootmac_0.6.0-1pipa1_all.deb' \
      '33e7f7e8aefe3d357e06e00628271d1ceb8ec1120074988263402afb8a9a62aa' 'swclock-offset_0.3.0-1pipa1_all.deb' \
      | sha256sum -c -; \
    mkdir -p /rootfs; \
    for deb in ./*.deb; do dpkg-deb -x "${deb}" /rootfs; done

FROM ${BASE_IMAGE}

COPY system_files/ /
COPY install-pipa.sh /usr/lib/armada-pipa/install-pipa.sh
COPY --from=pipa-payload /rootfs/ /

RUN chmod 0755 /usr/lib/armada-pipa/install-pipa.sh \
    && /usr/lib/armada-pipa/install-pipa.sh

RUN bootc container lint
