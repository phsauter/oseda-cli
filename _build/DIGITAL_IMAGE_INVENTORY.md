<!--
SPDX-FileCopyrightText: 2026 Johannes Kepler University
SPDX-License-Identifier: Apache-2.0
-->

# Digital CI image inventory

This inventory is based on upstream commit
`9240a74b15ac6b8303bced22e0defd2416a4324c`.

## Current image architecture

The current build graph builds each tool in a dedicated `base-dev`-derived
image. The final image starts from the desktop-oriented `base` image, copies
the complete `/foss/tools/<tool>` artifact from every selected tool image, and
then installs the full image's Python environments, examples, KLayout add-ons,
and launch configuration.

`base` is not a suitable parent for a minimal digital image: it installs XFCE,
VNC/noVNC, Firefox, Jupyter, GUI applications, broad build dependencies, and
full-image Python packages. The digital image therefore starts directly from
`ubuntu:noble` and consumes the existing per-tool artifacts.

## Selected stages and artifacts

| Build stage | Runtime artifact copied into digital | Included commands or purpose |
| --- | --- | --- |
| `slang` | `/foss/tools/slang` | `slang` parser and elaborator |
| `verible` | `/foss/tools/verible` | Verible lint, format, and related utilities |
| `verilator` | `/foss/tools/verilator` | SystemVerilog compilation and simulation |
| `iverilog` | `/foss/tools/iverilog` | Icarus Verilog and `vvp` |
| `yosys` | `/foss/tools/yosys` | Yosys, ABC, EQY, SBY, MCY, and Yices2 |
| `slang-yosys-plugin` | `/foss/tools/slang-yosys-plugin` | Yosys-Slang frontend |
| `openroad-cli` | `/foss/tools/openroad` | OpenROAD built with `BUILD_GUI=OFF` |
| `riscv-gnu-toolchain` | `/foss/tools/riscv-gnu-toolchain` | Bare-metal GCC/G++, binutils, GDB, and Newlib |
| `pulp-tools` | only `bin/bender`, `bin/sv2v`, and `SOURCES` | PULP dependency resolution and SV conversion |
| `kepler-formal` | `/foss/tools/kepler-formal` | LEC/SEC formal checks |
| `uv` | `/foss/tools/uv` | Managed Python environment and `uvx` |

The PULP stage's older duplicate Verible distribution is deliberately not
copied. Surelog/UHDM and GHDL are deliberately outside the first artifact set.
The OpenROAD stage also supplies `/opt/or-tools`, because the current OpenROAD
binary dynamically links against that stage's OR-Tools and Abseil build.

## Exact first-image tool contract

The command manifest is
[`_tests/digital/manifests/digital-required.txt`](../_tests/digital/manifests/digital-required.txt).
In addition to those commands, the image provides Bash, Git, GNU Make, CMake,
Ninja, a native C/C++ compiler, Python 3, uv, cocotb, pytest, Tcl, Perl, and
normal archive/text-processing utilities used by hardware CI, including jq
for machine-readable reports and metadata. The common
repository-quality suite comprises Black, flake8, Tclint/Tclfmt, ShellCheck,
shfmt, yamllint, codespell, and REUSE. Ruby is installed only by the optional
KLayout derivative.

The existing RISC-V stage is multilib. It explicitly builds:

- `rv64gc/lp64d`
- `rv32i/ilp32`
- `rv32e/ilp32e`
- `rv32imcb/ilp32`

The RV32 smoke test uses Croc's `rv32i_zicsr/ilp32` combination to verify that
the toolchain accepts the project-relevant extension spelling.

## PULP CI coverage

The selected contract covers the public in-container work seen in the
applicable PULP repositories:

- `common_cells`: Bender file-list generation, Slang parsing/elaboration, and
  Verible linting.
- `croc`: Bender-managed RTL, bare-metal RV32 software compilation, Verilator
  simulation, Yosys/Yosys-Slang synthesis, and OpenROAD execution when a PDK
  is mounted. KLayout-dependent signoff steps need a separate environment.
- `pulp-actions`: installed Bender can be used by actions that accept a
  compatible preinstalled version. The Slang review action currently creates
  its own uv/pyslang environment, and the RISC-V action downloads its pinned
  toolchain; those are action-level reproducibility choices rather than
  missing image commands.

GitHub-specific helpers such as `reviewdog` are not installed globally. An
action that owns such a helper should continue to fetch its pinned version.

## Runtime package groups

The authoritative list is
[`images/iic-osic-tools/digital/install_runtime.sh`](images/iic-osic-tools/digital/install_runtime.sh).
It uses `--no-install-recommends` and removes APT metadata in the same layer.
The initial dependency groups are:

- CI shell and source tools: Bash, Git, patch, curl, certificates, core
  archive utilities, `file`, GNU awk, `bc`, `time`, Perl, Tcl, ShellCheck,
  shfmt, and jq.
- Container initialization: the full image's shared numeric UID/GID identity
  helper and `libnss-wrapper`, called by a digital-only transparent entrypoint.
  No graphical startup script or service is copied.
- Project compilation: Make, CMake, Ninja, GCC/G++, binutils, and
  `pkg-config`. A native compiler, ccache, mold, and zlib headers are required
  by the repository's Verilator build and its generated FST-capable models.
- Python: CPython, venv support, and a single uv-managed environment containing
  cocotb, pytest, Black, flake8, Tclint/Tclfmt, yamllint, codespell, and REUSE.
  Black 25.12.0 and yamllint 1.37.1 are the newest releases compatible with
  Tclint 0.7.0's pinned PathSpec dependency; this also matches
  SiliconCompiler 0.37.12's lint-extra Tclint version. PyYAML 6.0.3 is declared
  directly (rather than merely inherited through yamllint) because Croc's
  license checker imports `yaml`.
- Native EDA runtime libraries: the required Boost, GMP/MPFR/MPC, Tcl,
  readline, YAML, TBB, and spdlog libraries needed by the copied binaries.
- OpenROAD runtime support: the separate `openroad-cli` artifact is built with
  `BUILD_GUI=OFF` and does not dynamically link Qt, X11, OpenGL, or Mesa.

The native-library list was validated with `ldd`/`readelf` and the complete
functional smoke suite.

## Components excluded from digital

The negative command manifest is
[`_tests/digital/manifests/full-only.txt`](../_tests/digital/manifests/full-only.txt).
The image does not copy PDKs, examples, desktop configuration, XFCE, VNC,
noVNC, browsers, notebooks, analog/SPICE/RF tools, schematic editors, FPGA
collections, vendor tools, Surelog/UHDM, GHDL, NVC, or full-image Python
package sets. KLayout and SiliconCompiler are available only in explicitly
selected derivative targets.

## Proposed stage structure

```text
existing per-tool build stages
             │
openroad-cli ─┐
ubuntu:noble ─┴─> digital
                    ├──> digital-klayout
                    ├──> digital-siliconcompiler
                    ├──> digital-klayout-siliconcompiler
                    └──> full (after independent image validation)
```

The `digital` target references only the selected tool stages, so BuildKit does
not need to build analog, RF, desktop, or PDK stages. The existing `image-full`
target remains unchanged during initial image validation.

## Files in the initial implementation

- `_build/docker-bake.hcl`
- `_build/images/openroad/Dockerfile`
- `_build/images/openroad/scripts/install.sh`
- `_build/images/iic-osic-tools/Dockerfile.digital`
- `_build/images/iic-osic-tools/digital/install_runtime.sh`
- `_build/images/iic-osic-tools/digital/install_klayout_runtime.sh`
- `_build/images/iic-osic-tools/digital/prune_runtime.sh`
- `_build/images/iic-osic-tools/digital/setup_klayout.sh`
- `_build/images/iic-osic-tools/digital/setup_tools.sh`
- `_tests/digital/manifests/*`
- `_tests/digital/fixtures/*`
- `_tests/digital/run_smoke_tests.sh`
- `_tests/digital/run_entrypoint_tests.sh`
- `_build/DIGITAL_IMAGE_NOTES.md`
- `_build/DIGITAL_IMAGE_INVENTORY.md`

## Smoke-test plan

The test runner checks every required command and confirms that representative
full-only commands are absent. It then performs real operations:

1. parse SystemVerilog with Slang;
2. lint and format it with Verible;
3. simulate it with Icarus;
4. compile and simulate it with Verilator, including FST support;
5. synthesize it with native Yosys and the Yosys-Slang frontend;
6. generate a dependency-free file list with Bender and convert SV with sv2v;
7. prove equivalent designs and reject a non-equivalent design with Kepler;
8. execute a minimal OpenROAD Tcl script;
9. compile and inspect RV32 and RV64 bare-metal ELF files;
10. import Click, cocotb, and pytest;
11. generate a tiny GDS in KLayout batch mode when selected;
12. import SiliconCompiler and construct a design when selected;
13. format and lint Python, Tcl, shell, and YAML fixtures;
14. spell-check fixtures and validate a minimal REUSE-compliant project;
15. query a small JSON tool manifest with jq.

The separate entrypoint suite verifies transparent direct-command execution,
PID 1 replacement, fixed and arbitrary numeric UID/GID identity, XDG runtime
directories, project `.designinit` sourcing, the absence of graphical startup
commands, and the non-graphical default command.

A later mounted-PDK integration test will exercise an actual OpenROAD flow
without placing a PDK in the image. KLayout signoff can be tested separately.

## Full-image inheritance assessment

No artifact-layout blocker has been identified: the full image can
conceptually extend `digital` and copy the remaining artifacts. The main
compatibility risk is foundational configuration rather than tool layout. The
current full image relies on `/headless`, its startup entrypoint, dynamically
generated user identity, desktop environment, Python environments, and a large
base-package set. Conversion should therefore happen only after the full-only
setup has been replayed on `digital` and the existing full test suite shows
that paths, entrypoint behavior, GUI behavior, PDK handling, and UID/GID
behavior are unchanged.

KLayout is not a blocker to inheritance. Its 207 MiB artifact plus the
Qt6/Ruby/runtime closure is disproportionate for the core CLI image, so it is
available as an optional derivative target.

Pyosys is deferred from the first contract. The Yosys artifact does not
currently install its Python module under `/foss/tools/yosys`; the published
full image instead has a separate PyPI `pyosys` 0.60 installation while its
Yosys executable is 0.66. Pulling in that duplicate, version-mismatched Yosys
build would work against the image's minimality and reproducibility goals.

The core external executables used by SiliconCompiler's synthesis and place
and route steps are present: sv2v, Yosys/Yosys-Slang, and OpenROAD. The
optional SiliconCompiler derivative installs the distribution's complete
declared dependency set but removes its 95 MiB FPGA demo data. Its mandatory
Streamlit/PyArrow/dashboard dependency closure is a documented upstream
packaging opportunity rather than something this image silently breaks.
