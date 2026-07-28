<!--
SPDX-FileCopyrightText: 2026 Johannes Kepler University
SPDX-License-Identifier: Apache-2.0
-->

# Digital CI image technical note

## Baseline

- Upstream: `https://github.com/iic-jku/IIC-OSIC-TOOLS.git`
- Upstream release: `2026.07`
- Base commit: `b7e6926578621c0a54b7e168f6583021933a40d2`
- Initial CLI prerelease: `2026.07.pre1`
- Base distribution: Ubuntu 24.04 (`ubuntu:noble`)
- Platforms: `linux/amd64`, `linux/arm64`

## Initial implementation scope

The initial implementation is an independent four-target Docker Bake matrix. It does
not change the existing `image-full` target or its publication group:

- `image-digital`
- `image-digital-klayout`
- `image-digital-siliconcompiler`
- `image-digital-klayout-siliconcompiler`

Included artifact sets:

- Slang and Verible
- Verilator and Icarus Verilog
- Yosys, its packaged companion tools, and the Yosys-Slang plugin
- Bender and sv2v from the PULP artifact
- Kepler Formal
- OpenROAD built with `BUILD_GUI=OFF`
- RISC-V GNU bare-metal multilib toolchain
- uv, cocotb, and pytest
- Black, flake8, Tclint/Tclfmt, ShellCheck, shfmt, yamllint, codespell,
  and REUSE

KLayout and SiliconCompiler 0.37.12 are optional derivative layers. The
SiliconCompiler derivatives retain its declared Python dependency set but omit
the packaged `data/demo_fpga` example (95 MiB unpacked), which is outside this
image's scope.

The PULP artifact's older duplicate Verible binaries are deliberately not
copied. The dedicated Verible artifact is the supported version.

Explicitly excluded:

- PDKs
- desktop, VNC, browser, notebook, and X server packages
- analog, RF, and SPICE tools
- Surelog/UHDM
- GHDL and NVC
- FPGA tool collections
- examples and demonstration projects
- KLayout and its Qt6/Ruby runtime closure from the core target
- MCY, including its Qt GUI; it is not required by the initial digital flows
- Verilator's developer-only `verilator_bin_dbg`; the optimized compiler and
  coverage postprocessor remain available

## Command-line startup

The digital image does not inherit `/dockerstartup/scripts/ui_startup.sh` and
cannot auto-select X11 or VNC. Its dedicated entrypoint reuses only the full
image's `generate_container_user.sh` helper with `libnss-wrapper`, initializes
the digital command environment, and then replaces itself with the requested
command using `exec`.

The CLI profile preserves the non-graphical behavior relevant to development
and CI: tool and user-local paths, Python and shared-library paths, shell and
Python cache settings, per-UID XDG runtime/data directories, and optional
`$DESIGNS/.designinit` sourcing. It deliberately excludes desktop aliases,
display probing, VNC/noVNC startup, XFCE, keyboard/display configuration, and
GUI process supervision.

Ubuntu Noble's built-in `ubuntu` account is removed, matching the full base,
so UID/GID 1000 and arbitrary `--user` values resolve consistently to the
runtime `designer` identity.

## PDK policy

The image contains no PDK. PDK-dependent smoke and integration tests will mount
a PDK read-only and set the project-specific environment paths explicitly.

## Source-build resource policy

The digital Verilator stage keeps the upstream 5.050 source pin and the full
image's default recipe behavior. Its digital-only build parameter compiles the
optimized compiler and coverage postprocessor sequentially, omitting the
developer debug compiler, then installs the selected artifacts serially because
Verilator's man-page generation invokes the installed compiler. This reduces
build work and runtime size without removing normal simulation or coverage
functionality.

The GHCR workflow limits BuildKit to two simultaneous build operations. Large
OpenROAD, RISC-V GCC, Verible, Kepler, and Verilator builds otherwise each use
all runner CPUs concurrently and can exceed a small hosted runner's memory.

## Known validation constraints

Docker is unavailable on the development host. Rootless Buildah can run inside
Singularity with the VFS storage driver and `vfs.ignore_chown_errors=true`.
The intermediate registry hostname is not resolvable from the current host.
Committed Dockerfiles continue to use the repository's per-tool artifacts; a
published full image may only be used locally as a temporary source for runtime
dependency analysis, never as the digital image's production base.

## Measurements

The comparable amd64 measurements below are from OCI images assembled with
Ubuntu Noble and the same selected tool artifacts as the Dockerfile. OpenROAD
was rebuilt from the repository's pinned commit with `BUILD_GUI=OFF`.
Compressed size is the sum of the exact gzip-compressed OCI layer sizes;
unpacked size is the sum of the exact uncompressed layer tar sizes.

| Target | Compressed | Unpacked | Added to core (compressed / unpacked) |
| --- | ---: | ---: | ---: |
| `image-digital` | 515.5 MiB | 1,425.3 MiB | — |
| `image-digital-klayout` | 719.2 MiB | 2,033.6 MiB | 203.7 / 608.3 MiB |
| `image-digital-siliconcompiler` | 651.7 MiB | 1,876.7 MiB | 136.2 / 451.4 MiB |
| `image-digital-klayout-siliconcompiler` | 854.1 MiB | 2,473.7 MiB | 338.6 / 1,048.4 MiB |

The corresponding decimal byte totals are:

| Target | Compressed bytes | Unpacked bytes |
| --- | ---: | ---: |
| `image-digital` | 540,534,341 | 1,494,510,080 |
| `image-digital-klayout` | 754,104,406 | 2,132,331,520 |
| `image-digital-siliconcompiler` | 683,325,179 | 1,967,823,360 |
| `image-digital-klayout-siliconcompiler` | 895,622,928 | 2,593,892,864 |

The table above records the four-way KLayout/SiliconCompiler comparison before
the common lint and format suite was added. The affected core was then rebuilt
twice to isolate the suite's cost:

| Core contents | Compressed | Unpacked | Added to baseline |
| --- | ---: | ---: | ---: |
| EDA and CI baseline | 515.5 MiB | 1,425.3 MiB | — |
| selected lint suite before jq | 526.8 MiB | 1,466.9 MiB | 11.3 / 41.6 MiB |
| selected lint suite plus jq (final core) | 527.2 MiB | 1,467.9 MiB | 11.7 / 42.6 MiB |
| evaluated with clang-format 17 (before jq) | 582.6 MiB | 1,644.2 MiB | 67.1 / 218.9 MiB |

The pre-jq core totals are 552,379,753 compressed OCI bytes and 1,538,148,352
unpacked layer bytes. Adding jq and its two runtime libraries measured
0.36 MiB compressed and 0.91 MiB as final-filesystem payload; the final row is
rounded from those controlled deltas. The CLI entrypoint, shared identity
helper, and `libnss-wrapper` keep the rounded total unchanged; together with jq
the measured final-filesystem delta is 0.98 MiB and the controlled SIF delta is
0.37 MiB. clang-format 17 was evaluated because
public Croc CI pins that formatter generation, but its LLVM closure alone added
55.8 MiB compressed and 177.3 MiB unpacked. It is deliberately left to
projects or CI actions that need it rather than imposed on every digital-image
pull.

For historical scale, the published amd64 `hpretl/iic-osic-tools:2026.06` manifest
contains 5,500,855,317 compressed layer bytes (5,246.0 MiB). Its corresponding
local SIF has a 15,601,132,149-byte apparent root filesystem (14,878.4 MiB).
The selected digital core is therefore about one tenth of the full image:
10.0% of its OCI pull size and 9.9% of its installed filesystem size. The OCI
comparison uses the exact Docker Hub manifest at amd64 digest
`sha256:fd38cb07a29d49d5f9720494cc4497cd8e8c80dfa06b4224d46447bc0f3c2ef0`;
the unpacked full-image number is a final-filesystem measurement rather than a
sum that double-counts files replaced across layers.

Python lint package versions are pinned. SiliconCompiler's `lint` extra pins
Tclint 0.7.0, whose PathSpec constraint is incompatible with Black 26 and
yamllint 1.38. The core therefore uses the latest compatible releases found
during the build, Black 25.12.0 and yamllint 1.37.1, rather than creating a
second Python environment. Installing SiliconCompiler 0.37.12 into the
resulting environment was also tested; Black, flake8, Tclint, yamllint, and
SiliconCompiler all import together.

These are pre-`2026.07` prototype estimates rather than release-registry
measurements and must be refreshed after the versioned image builds: the
host has no Docker daemon, so Buildah was run inside Singularity with the VFS
driver. The repository's intermediate registry was not resolvable; artifacts
were extracted locally from the published `2026.06` full image for this
measurement only. The production Dockerfile still consumes the individual
per-tool stages directly.

Largest selected artifact roots after runtime pruning on amd64:

| Artifact | Size |
| --- | ---: |
| RISC-V GNU toolchain | 372 MiB |
| KLayout | 207 MiB |
| OpenROAD | 99 MiB |
| Yosys and companions | 102 MiB |
| Slang | 35 MiB |
| Icarus Verilog | 7.1 MiB |

KLayout remains an optional derivative because its 207 MiB artifact and
current Qt6 build pull a multimedia-capable runtime closure. It largely
reintroduces the Mesa/X11 closure removed from the core, so the GUI-off
OpenROAD saving is intentionally concentrated in the targets without KLayout.

SiliconCompiler 0.37.12 has no supported GUI-off, dashboard-free, or CLI-only
installation extra. Its distribution metadata declares Streamlit, PyArrow,
Pandas, PySlang, and the dashboard packages as unconditional requirements;
`nodashboard` is a runtime option, not an installation option. Keeping that
metadata internally consistent costs 451.4 MiB unpacked. A supported upstream
`cli` extra would enable a substantially smaller derivative without ad-hoc
dependency removal.

Relative to the otherwise identical GUI-enabled OpenROAD prototype,
`BUILD_GUI=OFF` reduces the core and SiliconCompiler-only variants by about
80.3 MiB compressed and 234.8 MiB unpacked. The new OpenROAD binary has no
Qt, X11, OpenGL, or Mesa dynamic dependency. The existing GUI-enabled
`openroad` target remains unchanged for full-image compatibility; digital
targets use the separate `openroad-cli` Bake target.

## Validation record

All four amd64 variants passed the complete functional smoke suite on
2026-07-27. This includes real RTL parsing, linting, formatting, simulation,
synthesis, formal proof, OpenROAD Tcl execution, RV32/RV64 compilation,
KLayout batch GDS generation where selected, and SiliconCompiler import and
design construction where selected.
The final lint-enabled core additionally passed real Black, flake8,
Tclint/Tclfmt, ShellCheck, shfmt, yamllint, codespell, and REUSE checks on
deterministic temporary fixtures. The jq-enabled core reran the complete suite
and additionally queried a JSON tool manifest successfully.
The entrypoint-enabled assembled core reran the complete suite and separately
validated direct command execution, generated NSS identity, XDG directories,
login-shell environment idempotence, `.designinit` sourcing, and a
non-graphical default command.
An `ldd` scan of every executable ELF file under the selected tool roots found
no unresolved shared libraries after adding the explicit OR-Tools/Abseil
runtime and Ubuntu packages.

On 2026-07-29, the exact Verilator 5.050 digital recipe was independently
rebuilt in an Ubuntu Noble environment with GCC 13, Python 3.12, Flex 2.6.4,
Bison 3.8.2, and `help2man`. The optimized compiler and coverage postprocessor
compiled and installed successfully; both version commands ran, the developer
debug binary was absent, the recorded source pin matched `v5.050`, and the
installed compiler translated a SystemVerilog module into C++.

The smoke suite additionally exposed and now records:

- `ccache`, `mold`, and `zlib1g-dev` as Verilator model-build requirements;
- Click as an SBY runtime dependency;
- OR-Tools/Abseil as OpenROAD runtime dependencies; the CLI build removes
  the earlier Qt5, X11, OpenGL, Mesa, and LLVM runtime closure;
- the Qt6 compatibility, multimedia, UI tools, OpenGL, Git2, and Python
  libraries used by the current KLayout artifact, which justified making that
  artifact and dependency group optional;
- 95 MiB of SiliconCompiler FPGA demo data that can be removed without
  affecting the supported digital ASIC/CLI contract;
- 94.5 MiB unpacked in retained debug symbols across runtime ELF artifacts;
  stripping those symbols reduced the core compressed layer by 30.9 MiB and
  the complete functional suite still passed.
