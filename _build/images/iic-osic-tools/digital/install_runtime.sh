#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
    bash \
    bc \
    binutils \
    bzip2 \
    ca-certificates \
    ccache \
    cmake \
    curl \
    file \
    gawk \
    g++ \
    gcc \
    git \
    gzip \
    jq \
    libboost-iostreams1.83.0 \
    libboost-serialization1.83.0 \
    libboost-thread1.83.0 \
    libbz2-1.0 \
    libcapnp-1.0.1 \
    libcurl4 \
    libffi8 \
    libgcc-s1 \
    libgmp10 \
    libgomp1 \
    libmpc3 \
    libmpfr6 \
    libnss-wrapper \
    libpython3.12 \
    libreadline8 \
    libspdlog1.12 \
    libssl3 \
    libtbb12 \
    libtcl8.6 \
    libtomlplusplus3 \
    libyaml-cpp0.8 \
    libzstd1 \
    make \
    mold \
    ninja-build \
    patch \
    perl \
    pkg-config \
    python3 \
    python3-venv \
    shellcheck \
    shfmt \
    tcl \
    time \
    unzip \
    xz-utils \
    zip \
    zlib1g \
    zlib1g-dev

# Ubuntu Noble reserves UID/GID 1000 for an "ubuntu" account. The runtime
# identity wrapper, shared with the full image, supplies "designer" instead.
if getent passwd ubuntu >/dev/null; then
    userdel ubuntu
fi

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
