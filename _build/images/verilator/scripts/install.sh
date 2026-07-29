#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${VERILATOR_REPO_URL}" "${VERILATOR_NAME}"
cd "${VERILATOR_NAME}" || exit 1
git checkout "${VERILATOR_REPO_COMMIT}"
autoconf
unset VERILATOR_ROOT
./configure --prefix="${TOOLS}/${VERILATOR_NAME}"
if [[ ${VERILATOR_BUILD_DEBUG:-ON} == ON ]]; then
    make -j"$(nproc)"
    make install
else
    # The default target also builds the developer-only verilator_bin_dbg.
    # Keep the optimized compiler and the coverage postprocessor used by CI.
    make -C src -j"$(nproc)" opt
    make -C src -j"$(nproc)" ../bin/verilator_coverage_bin_dbg
    make \
        VL_INST_PUBLIC_BIN_FILES="verilator_bin verilator_coverage_bin_dbg" \
        installbin \
        installredirect \
        installdata \
        install-msg
fi # VERILATOR_BUILD_DEBUG
# and we strip the binaries to reduce size
find "${TOOLS}/${VERILATOR_NAME}" -type f -executable -exec strip {} \;

echo "${VERILATOR_NAME} ${VERILATOR_REPO_COMMIT}" > "${TOOLS}/${VERILATOR_NAME}/SOURCES"
