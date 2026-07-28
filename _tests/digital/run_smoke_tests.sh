#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"
MANIFESTS="${SCRIPT_DIR}/manifests"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
EXPECT_KLAYOUT="${EXPECT_KLAYOUT:-0}"
EXPECT_SILICONCOMPILER="${EXPECT_SILICONCOMPILER:-0}"
EXPECT_UPSTREAM_VERSION="${EXPECT_UPSTREAM_VERSION:-}"
EXPECT_IMAGE_VERSION="${EXPECT_IMAGE_VERSION:-}"

check_version_metadata() {
    if [[ -n ${EXPECT_UPSTREAM_VERSION} ]]; then
        [[ ${IIC_OSIC_TOOLS_VERSION} == "${EXPECT_UPSTREAM_VERSION}" ]]
    fi
    if [[ -n ${EXPECT_IMAGE_VERSION} ]]; then
        [[ ${OSEDA_CLI_VERSION} == "${EXPECT_IMAGE_VERSION}" ]]
    fi
}

check_required_tools() {
    while IFS= read -r tool; do
        [ -n "${tool}" ] || continue
        [[ ${tool} == \#* ]] && continue
        command -v "${tool}" >/dev/null || {
            echo "[ERROR] Required command not found: ${tool}" >&2
            return 1
        }
    done < "${MANIFESTS}/digital-required.txt"
}

check_full_only_tools_absent() {
    while IFS= read -r tool; do
        [ -n "${tool}" ] || continue
        [[ ${tool} == \#* ]] && continue
        if command -v "${tool}" >/dev/null 2>&1; then
            echo "[ERROR] Full-only command is present: ${tool}" >&2
            return 1
        fi
    done < "${MANIFESTS}/full-only.txt"
}

check_optional_tools() {
    if [[ ${EXPECT_KLAYOUT} == 1 ]]; then
        command -v klayout >/dev/null
    elif command -v klayout >/dev/null 2>&1; then
        echo "[ERROR] Optional KLayout command is unexpectedly present" >&2
        return 1
    fi

    if [[ ${EXPECT_SILICONCOMPILER} == 1 ]]; then
        python -c "import siliconcompiler"
    elif python -c "import siliconcompiler" >/dev/null 2>&1; then
        echo "[ERROR] Optional SiliconCompiler package is unexpectedly present" >&2
        return 1
    fi
}

print_versions() {
    slang --version
    verible-verilog-lint --version
    verible-verilog-format --version
    verilator --version
    iverilog -V
    yosys -V
    openroad -version
    bender --version
    sv2v --numeric-version
    kepler-formal --help >/dev/null
    jq --version
    riscv64-unknown-elf-gcc --version
    riscv64-unknown-elf-objdump --version
}

run_rtl_tests() {
    cp "${FIXTURES}/simple.sv" "${FIXTURES}/simple_tb.sv" "${FIXTURES}/Bender.yml" "${TMP}/"
    cd "${TMP}"

    slang --lint-only simple.sv simple_tb.sv
    # Fixture names intentionally describe their role rather than module names.
    verible-verilog-lint --rules=-module-filename simple.sv simple_tb.sv
    verible-verilog-format simple.sv > simple-formatted.sv

    iverilog -g2012 -s simple_tb -o simple.vvp simple.sv simple_tb.sv
    vvp simple.vvp | grep -q VERILATOR_SMOKE_OK

    verilator --binary --timing --trace-fst -Wno-fatal \
        --top-module simple_tb simple.sv simple_tb.sv
    ./obj_dir/Vsimple_tb | grep -q VERILATOR_SMOKE_OK

    yosys -Q -q -p "read_verilog -sv simple.sv; synth -top adder; write_json adder.json"
    yosys -Q -q -p "read_slang --top adder simple.sv; synth -top adder"

    bender script flist-plus > bender.f
    grep -q simple.sv bender.f

    sv2v simple.sv > simple-v2v.v
    iverilog -g2012 -s adder -o simple-v2v.vvp simple-v2v.v
}

run_formal_test() {
    cp \
        "${FIXTURES}/equivalent_a.v" \
        "${FIXTURES}/equivalent_b.v" \
        "${FIXTURES}/formal.sby" \
        "${FIXTURES}/formal.sv" \
        "${FIXTURES}/not_equivalent.v" \
        "${TMP}/"
    cd "${TMP}"

    sby -f formal.sby

    kepler-formal -verilog equivalent_a.v equivalent_b.v | tee kepler-equivalent.log
    grep -q "No difference was found" kepler-equivalent.log

    # Kepler reports a mismatch in its output but currently returns zero.
    kepler-formal -verilog equivalent_a.v not_equivalent.v | tee kepler-not-equivalent.log
    grep -q "Difference was found" kepler-not-equivalent.log
}

run_openroad_test() {
    if ldd "$(command -v openroad)" |
        grep -Eq 'lib(Qt|GL|OpenGL|X11|xcb|Xext)'; then
        echo "[ERROR] OpenROAD CLI unexpectedly links a GUI library" >&2
        return 1
    fi

    cat > "${TMP}/openroad-smoke.tcl" <<'EOF'
puts "OPENROAD_SMOKE_OK"
exit
EOF
    openroad -exit "${TMP}/openroad-smoke.tcl" | grep -q OPENROAD_SMOKE_OK
}

run_klayout_test() {
    [[ ${EXPECT_KLAYOUT} == 1 ]] || return 0
    cp "${FIXTURES}/klayout_smoke.py" "${TMP}/"
    cd "${TMP}"
    klayout -zz -r klayout_smoke.py | grep -q KLAYOUT_SMOKE_OK
    test -s klayout-smoke.gds
}

run_siliconcompiler_test() {
    [[ ${EXPECT_SILICONCOMPILER} == 1 ]] || return 0
    python -c \
        "import siliconcompiler; design = siliconcompiler.Design('smoke'); print(siliconcompiler.__version__)"
}

run_riscv_test() {
    cp "${FIXTURES}/baremetal.c" "${TMP}/"
    cd "${TMP}"

    riscv64-unknown-elf-gcc \
        -march=rv32i_zicsr -mabi=ilp32 -nostdlib -Wl,-e,_start \
        baremetal.c -o baremetal-rv32.elf
    riscv64-unknown-elf-objcopy -O verilog baremetal-rv32.elf baremetal-rv32.hex
    riscv64-unknown-elf-objdump -d baremetal-rv32.elf > baremetal-rv32.dump
    riscv64-unknown-elf-readelf -h baremetal-rv32.elf | grep -q "Class:.*ELF32"

    riscv64-unknown-elf-gcc \
        -march=rv64gc -mabi=lp64d -nostdlib -Wl,-e,_start \
        baremetal.c -o baremetal-rv64.elf
    riscv64-unknown-elf-readelf -h baremetal-rv64.elf | grep -q "Class:.*ELF64"

    riscv64-unknown-elf-gcc -print-multi-lib
}

run_python_test() {
    python -c "import click, cocotb, pytest, yaml"
}

run_ci_utility_tests() {
    printf '%s\n' '{"tools":["slang","yosys","openroad"]}' |
        jq -e '.tools | index("yosys") != null' >/dev/null
}

run_lint_format_tests() {
    cat > "${TMP}/format_smoke.py" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
items=[1,2,3]
print(items)
EOF
    black "${TMP}/format_smoke.py"
    black --check "${TMP}/format_smoke.py"
    flake8 "${TMP}/format_smoke.py"

    cat > "${TMP}/format_smoke.tcl" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
set value 42
puts $value
EOF
    tclint "${TMP}/format_smoke.tcl"
    tclfmt "${TMP}/format_smoke.tcl" > "${TMP}/format_smoke.formatted.tcl"
    tclint "${TMP}/format_smoke.formatted.tcl"

    cat > "${TMP}/format_smoke.sh" <<'EOF'
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
value=42
printf '%s\n' "${value}"
EOF
    shellcheck "${TMP}/format_smoke.sh"
    shfmt -d "${TMP}/format_smoke.sh"

    cat > "${TMP}/format_smoke.yml" <<'EOF'
# SPDX-License-Identifier: Apache-2.0
name: digital-lint-smoke
enabled: true
EOF
    yamllint -d relaxed "${TMP}/format_smoke.yml"
    codespell "${TMP}/format_smoke.py" "${TMP}/format_smoke.tcl"

    mkdir -p "${TMP}/reuse-smoke/LICENSES"
    cat > "${TMP}/reuse-smoke/LICENSES/LicenseRef-Smoke.txt" <<'EOF'
Test-only license text for the digital image smoke fixture.
EOF
    cat > "${TMP}/reuse-smoke/reuse_smoke.py" <<'EOF'
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: LicenseRef-Smoke
print("REUSE_SMOKE_OK")
EOF
    (
        cd "${TMP}/reuse-smoke"
        reuse lint
    )
}

check_required_tools
check_version_metadata
check_full_only_tools_absent
check_optional_tools
print_versions
run_rtl_tests
run_formal_test
run_openroad_test
run_klayout_test
run_riscv_test
run_python_test
run_ci_utility_tests
run_lint_format_tests
run_siliconcompiler_test

echo "[INFO] All digital image smoke tests passed."
