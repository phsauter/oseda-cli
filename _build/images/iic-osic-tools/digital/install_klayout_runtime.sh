#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
    libegl1 \
    libgit2-1.7 \
    libqt6core5compat6 \
    libqt6core6t64 \
    libqt6gui6 \
    libqt6multimedia6 \
    libqt6network6 \
    libqt6opengl6 \
    libqt6openglwidgets6 \
    libqt6printsupport6 \
    libqt6sql6 \
    libqt6svg6 \
    libqt6uitools6 \
    libqt6widgets6 \
    libqt6xml6 \
    ruby

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/*
