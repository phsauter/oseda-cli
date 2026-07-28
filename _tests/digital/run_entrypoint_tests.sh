#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 IMAGE" >&2
    exit 2
fi

IMAGE=$1
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

# A direct command must replace PID 1 and retain the digital environment.
# shellcheck disable=SC2016
"${CONTAINER_ENGINE}" run --rm "${IMAGE}" sh -eu -c '
    test "$$" -eq 1
    test "$TOOLS" = /foss/tools
    test "$VIRTUAL_ENV" = /opt/oseda-python
    command -v yosys >/dev/null
    yosys -V >/dev/null
    test ! -e /dockerstartup/scripts/ui_startup.sh
    ! command -v vncserver >/dev/null
    ! command -v websockify >/dev/null
'

# Match the full image's runtime identity behavior for arbitrary numeric IDs.
# shellcheck disable=SC2016
"${CONTAINER_ENGINE}" run --rm --user 12345:23456 "${IMAGE}" sh -eu -c '
    test "$(id -u)" = 12345
    test "$(id -g)" = 23456
    test "$(id -un)" = designer
    test "$USER" = designer
    getent passwd designer | grep -q "^designer:x:12345:23456:"
    test -d "$XDG_RUNTIME_DIR"
    test -d "$XDG_DATA_HOME"
'

# Project setup remains opt-in through the same DESIGNS/.designinit convention
# as the full image, without sourcing an arbitrary HOME/.bashrc.
cat > "${TMP}/.designinit" <<'EOF'
export DIGITAL_DESIGNINIT_SMOKE=ready
EOF
# shellcheck disable=SC2016
"${CONTAINER_ENGINE}" run --rm \
    --mount "type=bind,src=${TMP},dst=/smoke-designs,readonly" \
    -e DESIGNS=/smoke-designs \
    "${IMAGE}" \
    sh -eu -c 'test "$DIGITAL_DESIGNINIT_SMOKE" = ready'

# With no explicit command, the default Bash command should exit normally in
# non-interactive operation rather than starting or waiting for graphical UI.
"${CONTAINER_ENGINE}" run --rm "${IMAGE}"

echo "[INFO] All digital entrypoint tests passed."
