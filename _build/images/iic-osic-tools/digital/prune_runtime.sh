#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# Runtime images do not support compiling against these host-side tool SDKs.
rm -rf \
    "${TOOLS}/openroad/include" \
    "${TOOLS}/slang/include" \
    "${TOOLS}/slang/lib/cmake" \
    "${TOOLS}/slang/lib/pkgconfig" \
    "${TOOLS}/slang/share/pkgconfig" \
    /opt/or-tools/include \
    /opt/or-tools/lib/cmake \
    /opt/or-tools/lib/pkgconfig

rm -f \
    "${TOOLS}/openroad/lib/libOpenSTA.a" \
    "${TOOLS}/slang/lib/"*.a \
    "${TOOLS}/yosys/lib/libyices.a"

find "${TOOLS}/kepler-formal/lib" /opt/or-tools/lib \
    -type f -name '*.a' -delete

# Preserve Newlib and target libraries, but omit host-side toolchain
# documentation and GCC plugin-development headers.
rm -rf \
    "${TOOLS}/riscv-gnu-toolchain/share/info" \
    "${TOOLS}/riscv-gnu-toolchain/share/locale" \
    "${TOOLS}/riscv-gnu-toolchain/share/man"
find "${TOOLS}/riscv-gnu-toolchain/lib/gcc" \
    -type d -path '*/plugin/include' -prune -exec rm -rf {} +

# The upstream tool artifacts retain debug symbols in several runtime ELF
# files. Keep build IDs while dropping symbols that are not used by execution.
# readelf filters out scripts and data files before invoking the host strip.
find \
    "${TOOLS}/iverilog" \
    "${TOOLS}/kepler-formal" \
    "${TOOLS}/openroad" \
    "${TOOLS}/slang-yosys-plugin" \
    "${TOOLS}/yosys" \
    /opt/or-tools \
    -type f \
    \( -perm /111 -o -name '*.so' -o -name '*.so.*' \
       -o -name '*.tgt' -o -name '*.vpi' \) \
    -exec bash -c '
        for runtime_file; do
            if readelf -h "${runtime_file}" >/dev/null 2>&1; then
                strip --strip-unneeded "${runtime_file}"
            fi
        done
    ' bash {} +
