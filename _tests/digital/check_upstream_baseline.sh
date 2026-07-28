#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "${REPO_ROOT}/_build/images/iic-osic-tools/digital/version.env"
UPSTREAM_REF="${UPSTREAM_COMMIT}^{commit}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

git rev-parse --verify "${UPSTREAM_REF}" >/dev/null
git merge-base --is-ancestor "${UPSTREAM_REF}" HEAD
if git rev-parse --verify --quiet "refs/tags/${UPSTREAM_VERSION}^{commit}" >/dev/null; then
    [[ $(git rev-parse "refs/tags/${UPSTREAM_VERSION}^{commit}") == "${UPSTREAM_COMMIT}" ]]
fi

# The published manifest and all selected source-build recipes stay byte-for-
# byte aligned with the declared upstream release. The narrowly parameterized
# OpenROAD, Verilator, and Yosys differences are validated separately below;
# their defaults retain the upstream/full behavior.
git diff --quiet "${UPSTREAM_REF}" -- _build/tool_metadata.yml

for tool in \
    iverilog \
    kepler-formal \
    pulp-tools \
    riscv-gnu-toolchain \
    slang \
    slang-yosys-plugin \
    uv \
    verible; do
    git diff --quiet "${UPSTREAM_REF}" -- "_build/images/${tool}"
done

git show "${UPSTREAM_REF}:_build/images/verilator/Dockerfile" \
    > "${TMP}/verilator.Dockerfile.upstream"
sed '/^ARG VERILATOR_BUILD_DEBUG="ON"$/d' \
    "${REPO_ROOT}/_build/images/verilator/Dockerfile" \
    > "${TMP}/verilator.Dockerfile.digital"
cmp "${TMP}/verilator.Dockerfile.upstream" "${TMP}/verilator.Dockerfile.digital"

git show "${UPSTREAM_REF}:_build/images/verilator/scripts/install.sh" \
    > "${TMP}/verilator-install.upstream.sh"
sed \
    -e '/^if \[\[ ${VERILATOR_BUILD_DEBUG:-ON} == ON \]\]; then$/d' \
    -e '/^else$/,/^fi # VERILATOR_BUILD_DEBUG$/d' \
    -e 's/^    make -j"$(nproc)"$/make -j"$(nproc)"/' \
    -e 's/^    make install$/make install/' \
    "${REPO_ROOT}/_build/images/verilator/scripts/install.sh" \
    > "${TMP}/verilator-install.digital.sh"
cmp "${TMP}/verilator-install.upstream.sh" "${TMP}/verilator-install.digital.sh"

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

git show "${UPSTREAM_REF}:_build/images/yosys/Dockerfile" \
    > "${TMP}/yosys.Dockerfile.upstream"
sed '/^ARG YOSYS_INSTALL_MCY="ON"$/d' \
    "${REPO_ROOT}/_build/images/yosys/Dockerfile" \
    > "${TMP}/yosys.Dockerfile.digital"
cmp "${TMP}/yosys.Dockerfile.upstream" "${TMP}/yosys.Dockerfile.digital"

git show "${UPSTREAM_REF}:_build/images/yosys/scripts/install.sh" \
    > "${TMP}/yosys-install.upstream.sh"
sed \
    -e '/^if \[\[ ${YOSYS_INSTALL_MCY:-ON} == ON \]\]; then$/d' \
    -e '/^fi # YOSYS_INSTALL_MCY$/d' \
    "${REPO_ROOT}/_build/images/yosys/scripts/install.sh" \
    > "${TMP}/yosys-install.digital.sh"
cmp "${TMP}/yosys-install.upstream.sh" "${TMP}/yosys-install.digital.sh"

echo "[INFO] Digital tool pins match upstream ${UPSTREAM_VERSION}."
