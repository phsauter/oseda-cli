#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -e

# Provide a passwd/group identity when the runtime selects a numeric UID/GID.
# This is shared with the full image but intentionally does not start any UI.
# shellcheck source=/dev/null
source /usr/local/libexec/iic-osic-tools/generate_container_user.sh

# Commands passed directly to the container need the same environment as an
# interactive shell; do not rely on Bash startup-file semantics.
# shellcheck source=/dev/null
source /etc/profile.d/iic-osic-tools-digital.sh

if [ "$#" -eq 0 ]; then
    set -- bash
fi

exec "$@"
