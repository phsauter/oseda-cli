#!/bin/bash
# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

mkdir -p "${TOOLS}/bin" "${TOOLS}/yosys/share/yosys/plugins"

for bindir in "${TOOLS}"/*/bin; do
    [ -d "${bindir}" ] || continue
    for executable in "${bindir}"/*; do
        [ -f "${executable}" ] || [ -L "${executable}" ] || continue
        ln -sfn "${executable}" "${TOOLS}/bin/$(basename "${executable}")"
    done
done

# MCY's optional GUI is the only Qt6 consumer in the Yosys artifact.
rm -f "${TOOLS}/yosys/bin/mcy-gui" "${TOOLS}/bin/mcy-gui"

# Load only the SystemVerilog frontend provided by the digital image.
ln -sfn \
    "${TOOLS}/slang-yosys-plugin/slang.so" \
    "${TOOLS}/yosys/share/yosys/plugins/slang.so"
rm -f "${TOOLS}/bin/yosys"
cat > "${TOOLS}/bin/yosys" <<'EOF'
#!/bin/bash
if [[ ${1:-} == "-h" ]]; then
    exec -a "$0" "$TOOLS/yosys/bin/yosys" "$@"
else
    exec -a "$0" "$TOOLS/yosys/bin/yosys" -m slang "$@"
fi
EOF
chmod 755 "${TOOLS}/bin/yosys"

cat > /etc/profile.d/iic-osic-tools-digital.sh <<'EOF'
if [ -z "${FOSS_INIT_DONE+x}" ]; then
    export TOOLS=${TOOLS:-/foss/tools}
    export PDK_ROOT=${PDK_ROOT:-/foss/pdks}
    export DESIGNS=${DESIGNS:-/foss/designs}
    export HOME=${HOME:-/workspace}
    export USER=${USER:-designer}
    export VIRTUAL_ENV=${VIRTUAL_ENV:-/opt/oseda-python}
    export PATH="$HOME/.local/bin:$VIRTUAL_ENV/bin:$TOOLS/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    export PYTHONPATH="$TOOLS/yosys/share/yosys/python3${PYTHONPATH:+:$PYTHONPATH}"
    export LD_LIBRARY_PATH="/opt/or-tools/lib:$TOOLS/iverilog/lib:$TOOLS/kepler-formal/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PYTHONPYCACHEPREFIX=${PYTHONPYCACHEPREFIX:-/tmp/pycache}
    export SHELL=${SHELL:-/bin/bash}

    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
    fi

    export XDG_DATA_HOME=${XDG_DATA_HOME:-/tmp/data-$(id -u)}
    if [ ! -d "$XDG_DATA_HOME" ]; then
        mkdir -p "$XDG_DATA_HOME"
    fi

    export FOSS_INIT_DONE=1
fi

if [ -n "${DESIGNS:-}" ] && [ -f "$DESIGNS/.designinit" ]; then
    # shellcheck source=/dev/null
    source "$DESIGNS/.designinit"
fi
EOF
chmod 644 /etc/profile.d/iic-osic-tools-digital.sh
