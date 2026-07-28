# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:noble AS digital-build-base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    TOOLS=/foss/tools

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        autotools-dev \
        bc \
        binutils \
        bison \
        build-essential \
        capnproto \
        ca-certificates \
        clang \
        cmake \
        curl \
        flex \
        gawk \
        git \
        gperf \
        libboost-filesystem-dev \
        libboost-iostreams-dev \
        libboost-program-options-dev \
        libboost-python-dev \
        libboost-serialization-dev \
        libboost-system-dev \
        libboost-thread-dev \
        libbz2-dev \
        libcapnp-dev \
        libdw-dev \
        libeigen3-dev \
        libexpat1-dev \
        libffi-dev \
        libfl-dev \
        libgmp-dev \
        libgomp1 \
        libmpc-dev \
        libmpfr-dev \
        libomp-dev \
        libpcre2-dev \
        libreadline-dev \
        libtbb-dev \
        libtool \
        libyaml-cpp-dev \
        libzstd-dev \
        make \
        ninja-build \
        patch \
        patchutils \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        rustup \
        swig \
        tcl \
        tcl-dev \
        texinfo \
        unzip \
        wget \
        xz-utils \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${TOOLS}"

# OpenROAD dependencies that Ubuntu Noble does not provide at compatible
# versions. They remain in this build stage; only OpenROAD's required OR-Tools
# runtime is copied into the digital image.
RUN --mount=type=bind,source=images/base/scripts,target=/base-scripts \
    bash /base-scripts/31_install_or-tools.sh && \
    bash /base-scripts/32_install_cudd.sh && \
    bash /base-scripts/33_install_gtest.sh && \
    bash /base-scripts/35_install_lemon.sh && \
    ldconfig

RUN python3 -m pip install \
        --break-system-packages \
        --no-cache-dir \
        cxxheaderparser==1.9.2 \
        pybind11==3.0.4
