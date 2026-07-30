<!--
SPDX-FileCopyrightText: 2026 Johannes Kepler University
SPDX-License-Identifier: Apache-2.0
-->

# Digital CI image

The `image-digital` Bake target builds the Ubuntu-based command-line core
image. It does not contain a PDK or the full image's desktop and analog
tooling.

Release versions track an exact upstream release. The version contract is
recorded in `digital/version.env`: `IIC_OSIC_TOOLS_VERSION` identifies the
upstream tool baseline, while `OSEDA_CLI_VERSION` and the image tag identify a
particular CLI build of that baseline. For example, `2026.07`, `2026.07.1`,
and `2026.07.2` all use the tool pins from upstream `2026.07`.

The core also includes repository lint and format tooling: Verible, Slang,
Verilator, Black, flake8, Tclint/Tclfmt, ShellCheck, shfmt, yamllint,
codespell, REUSE, and jq.

Optional derivatives are:

- `image-digital-klayout`
- `image-digital-siliconcompiler`
- `image-digital-klayout-siliconcompiler`

From `_build`, build and load the native architecture:

```bash
docker buildx bake \
  --set image-digital.platform=linux/amd64 \
  --set image-digital.tags=iic-osic-tools:digital \
  --load \
  image-digital
```

Use `linux/arm64` on a native arm64 builder. A multi-platform registry or OCI
build can retain the target's default platform list:

```bash
docker buildx bake \
  --set image-digital.tags=registry.example/iic-osic-tools:digital \
  image-digital
```

Run the functional smoke suite from the repository root:

```bash
docker run --rm \
  --mount type=bind,src="$PWD/_tests/digital",dst=/tests,readonly \
  iic-osic-tools:digital \
  bash /tests/run_smoke_tests.sh
```

Test the container entrypoint, including arbitrary numeric UID/GID handling:

```bash
_tests/digital/run_entrypoint_tests.sh iic-osic-tools:digital
```

The digital entrypoint initializes only command-line environment and runtime
identity state. It does not copy or invoke the full image's X11, VNC, noVNC,
XFCE, browser, or notebook startup paths. Commands are executed directly with
`exec`, so normal container signal handling is preserved:

```bash
docker run --rm iic-osic-tools:digital yosys -V
docker run --rm -it iic-osic-tools:digital bash
```

For a derivative image, set the corresponding smoke-test expectations:

```bash
docker run --rm \
  --mount type=bind,src="$PWD/_tests/digital",dst=/tests,readonly \
  -e EXPECT_KLAYOUT=1 \
  -e EXPECT_SILICONCOMPILER=1 \
  iic-osic-tools:digital-klayout-siliconcompiler \
  bash /tests/run_smoke_tests.sh
```

Projects provide their own PDK for integration tests:

```bash
docker run --rm \
  --mount type=bind,src=/path/to/pdk,dst=/pdk,readonly \
  --mount type=bind,src="$PWD",dst=/workspace \
  -e PDK_ROOT=/pdk \
  iic-osic-tools:digital \
  make test
```

Building `image-digital` references only its selected per-tool stages. It does
not require analog, RF, desktop, example, or PDK stages.
