#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "${REPO_ROOT}/_build/images/iic-osic-tools/digital/version.env"
UPSTREAM_REF="${UPSTREAM_VERSION}^{commit}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

git rev-parse --verify "${UPSTREAM_REF}" >/dev/null
git merge-base --is-ancestor "${UPSTREAM_REF}" HEAD

# The published manifest and all selected source-build recipes stay byte-for-
# byte aligned with the declared upstream release. OpenROAD has one intentional
# difference, validated separately below: BUILD_GUI is parameterized so the
# digital target can set it to OFF while the full target retains ON.
git diff --quiet "${UPSTREAM_REF}" -- _build/tool_metadata.yml

for tool in \
    iverilog \
    kepler-formal \
    pulp-tools \
    riscv-gnu-toolchain \
    slang \
    slang-yosys-plugin \
    uv \
    verible \
    verilator \
    yosys; do
    git diff --quiet "${UPSTREAM_REF}" -- "_build/images/${tool}"
done

git show "${UPSTREAM_REF}:_build/images/openroad/Dockerfile" \
    > "${TMP}/Dockerfile.upstream"
sed '/^ARG OPENROAD_BUILD_GUI="ON"$/d' \
    "${REPO_ROOT}/_build/images/openroad/Dockerfile" \
    > "${TMP}/Dockerfile.digital"
cmp "${TMP}/Dockerfile.upstream" "${TMP}/Dockerfile.digital"

git show "${UPSTREAM_REF}:_build/images/openroad/scripts/install.sh" \
    > "${TMP}/install.upstream.sh"
sed 's/-DBUILD_GUI="${OPENROAD_BUILD_GUI:-ON}"/-DBUILD_GUI=ON/' \
    "${REPO_ROOT}/_build/images/openroad/scripts/install.sh" \
    > "${TMP}/install.digital.sh"
cmp "${TMP}/install.upstream.sh" "${TMP}/install.digital.sh"

echo "[INFO] Digital tool pins match upstream ${UPSTREAM_VERSION}."
