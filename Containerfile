ARG BASE_IMAGE=ghcr.io/armada-os/armada:testing
ARG PIPA_KERNEL_VERSION=7.1.7-pipa

FROM debian:13-slim AS pipa-payload

ARG PIPA_REPO_URL=https://thespider2.github.io/pipa-pkgs/repo/ubuntu

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /payload

RUN set -eux; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/linux-image-pipa_7.1.7-4pipa1_arm64.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/linux-modules-pipa_7.1.7-4pipa1_arm64.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/pipa-sound-conf_1.4-12pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/bootmac_0.6.0-1pipa1_all.deb"; \
    curl --retry 3 -fLO "${PIPA_REPO_URL}/swclock-offset_0.3.0-1pipa1_all.deb"; \
    printf '%s  %s\n' \
      'fedb8f120dbdb43ff2074d9732cddf5d79f238761c8f15e28954c474830c45e9' 'linux-image-pipa_7.1.7-4pipa1_arm64.deb' \
      'f0271d76444060749262f9844ea19ac6d98f7db1e76e3b1304bad28c31b6ec00' 'linux-modules-pipa_7.1.7-4pipa1_arm64.deb' \
      '48121bc2815f00c6fb6f25d1f42899338b240a8511b6ca8accd3a7795ffc9e72' 'pipa-sound-conf_1.4-12pipa1_all.deb' \
      '12e119491e8678223ac2d752b6877ee2ec623c21294aeec64fcc77d63dfa8350' 'bootmac_0.6.0-1pipa1_all.deb' \
      '33e7f7e8aefe3d357e06e00628271d1ceb8ec1120074988263402afb8a9a62aa' 'swclock-offset_0.3.0-1pipa1_all.deb' \
      | sha256sum -c -; \
    mkdir -p /rootfs; \
    for deb in ./*.deb; do dpkg-deb -x "${deb}" /rootfs; done

FROM ${BASE_IMAGE}
ARG PIPA_KERNEL_VERSION
ENV PIPA_KERNEL_VERSION=${PIPA_KERNEL_VERSION}

COPY system_files/etc/yum.repos.d/ /etc/yum.repos.d/
COPY install-pipa.sh /usr/lib/armada-pipa/install-pipa.sh
COPY --from=pipa-payload /rootfs/ /

RUN set -eux; \
    dnf install -y \
        alsa-ucm-conf-sm8250 \
        curl \
        pipa-dracut \
        pipa-sound-conf \
        qrtr-libs \
        tqftpserv \
        xiaomi-pipa-firmware; \
    mkdir -p /tmp/pipa-dsp-rpms; \
    cd /tmp/pipa-dsp-rpms; \
    curl --retry 3 -fLO \
        https://kojipkgs.fedoraproject.org/packages/qrtr/1.0/3.fc40/aarch64/qrtr-1.0-3.fc40.aarch64.rpm; \
    curl --retry 3 -fLO \
        https://kojipkgs.fedoraproject.org/packages/pd-mapper/1.0/5.fc40/aarch64/pd-mapper-1.0-5.fc40.aarch64.rpm; \
    printf '%s  %s\n' \
      '545208d284467e90aee236cdaa22aa64eedf157b16ffc0d49f698d8cdd74957ae' 'qrtr-1.0-3.fc40.aarch64.rpm' \
      'd9edbb7842fb3e992e7b8035c1cae3709a66dbfa0745451adcbfeda69820fcf7' 'pd-mapper-1.0-5.fc40.aarch64.rpm' \
      | sha256sum -c -; \
    rpm -i --nodeps ./*.rpm; \
    cd /; \
    rm -rf /tmp/pipa-dsp-rpms; \
    dnf clean all

COPY system_files/ /
COPY scripts/slim-image.sh /usr/lib/armada-pipa/slim-image.sh

RUN chmod 0755 /usr/lib/armada-pipa/install-pipa.sh \
    && chmod 0755 /usr/lib/armada-pipa/slim-image.sh \
    && /usr/lib/armada-pipa/install-pipa.sh \
    && /usr/lib/armada-pipa/slim-image.sh

RUN bootc container lint
