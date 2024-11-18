#
# Copyright (C) 2016-2024 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
# Unported License: http://creativecommons.org/licenses/by-sa/3.0/
#
# Attribution required: please include my name in any derivative and let me
# know how you have improved it!

FROM debian:bookworm-slim AS base
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt -yqq update
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt -yqq --no-install-recommends install iptables nftables

FROM base AS build

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt -yqq --no-install-recommends install \
        gcc make flex bison pkg-config \
        libcap-ng-dev libcurl4-nss-dev libevent-dev libnss3-dev libpam0g-dev

WORKDIR /opt/src
ARG SWAN_VER=5.1
ARG SWAN_URL=https://github.com/libreswan/libreswan/archive/v${SWAN_VER}.tar.gz
# ARG SWAN_URL=https://download.libreswan.org/libreswan-${SWAN_VER}.tar.gz
ADD --link "${SWAN_URL}" libreswan.tar.gz
RUN tar zxf libreswan.tar.gz

WORKDIR /opt/src/libreswan-${SWAN_VER}
COPY --link <<EOF Makefile.inc.local
WERROR_CFLAGS=-w -s
USE_DNSSEC=false
USE_SYSTEMD_WATCHDOG=false
USE_DH2=true
USE_NSS_KDF=false
USE_NFTABLES=true
INITSYSTEM=sysvinit
FINALNSSDIR=/etc/ipsec.d
NSSDIR=/etc/ipsec.d
DESTDIR=/opt/libreswan
EOF
RUN mkdir -p /opt/libreswan
RUN make -s base
RUN make -s install-base

FROM base AS output

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    apt -yqq --no-install-recommends install \
        libcap-ng0 libcurl3-nss libevent-2.1-7 libevent-pthreads-2.1-7 libnss3-tools libpam0g
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    apt -yqq --no-install-recommends install \
        dnsutils iproute2 openssl uuid-runtime wget xl2tpd

WORKDIR /opt/src
ARG IKEV2_URL=https://github.com/hwdsl2/setup-ipsec-vpn/raw/9a625dba296d488f89c2213627931b8685efd354/extras/ikev2setup.sh
ADD --link --chmod=755 "${IKEV2_URL}" /opt/src/ikev2.sh
RUN ln -s /opt/src/ikev2.sh /usr/local/bin/ikev2.sh
COPY --link --chmod=755 ./run.sh /opt/src/run.sh
COPY --link --from=build /opt/libreswan/ /

EXPOSE 500/udp 4500/udp
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="IPsec VPN Server on Docker" \
    org.opencontainers.image.description="Docker image to run an IPsec VPN server, with IPsec/L2TP, Cisco IPsec and IKEv2." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-ipsec-vpn-server" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-ipsec-vpn-server" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-ipsec-vpn-server"
