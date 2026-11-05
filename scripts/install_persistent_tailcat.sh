#!/usr/bin/env bash
# ==============================================================================
# install_persistent_tailcat.sh
# Deterministic Tailcat Ingress Installation & Reboot Persistence Blueprint
# ==============================================================================
# Usage:
#   export TAILCAT_AUTHORIZED_KEYS="ssh-ed25519 AAAA... developer@host"
#   ./install_persistent_tailcat.sh [REGION]
# Example:
#   export TAILCAT_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
#   ./install_persistent_tailcat.sh tok
# ==============================================================================
set -euo pipefail

REGION="${1:-tok}"
HOME_DIR="${HOME:-/home/jules}"
LOCAL_BIN="${HOME_DIR}/.local/bin"
TAILCAT_BIN="${LOCAL_BIN}/tailcat"
CONFIG_DIR="${HOME_DIR}/.config/tailcat"
KEYS_DIR="${CONFIG_DIR}/keys"
SAVED_ADDR_FILE="${CONFIG_DIR}/saved_address.txt"
SAVED_RESOLVED_FILE="${CONFIG_DIR}/saved_resolved_address.txt"

echo "[1/4] Ensuring persistent binary location in ${LOCAL_BIN}..."
mkdir -p "${LOCAL_BIN}" "${KEYS_DIR}"
if [ ! -f "${TAILCAT_BIN}" ]; then
    if [ -f "${HOME_DIR}/go/bin/tailcat" ]; then
        cp -p "${HOME_DIR}/go/bin/tailcat" "${TAILCAT_BIN}"
    elif command -v tailcat >/dev/null; then
        cp -p "$(command -v tailcat)" "${TAILCAT_BIN}"
    else
        echo "ERROR: tailcat binary not found in PATH, ~/.local/bin, or ~/go/bin"
        exit 1
    fi
fi
chmod +x "${TAILCAT_BIN}"

echo "[2/4] Verifying region-pinned key (region: ${REGION})..."
if [ ! -f "${KEYS_DIR}/default.private.json" ]; then
    echo "  Generating new region-pinned key 'default' for region '${REGION}'..."
    NEW_ADDR=$("${TAILCAT_BIN}" genkey --key=default --region="${REGION}")
    echo "${NEW_ADDR}" > "${SAVED_ADDR_FILE}"
else
    echo "  Region-pinned key 'default' already exists in ${KEYS_DIR}/default.private.json"
fi

if [ ! -f "${SAVED_ADDR_FILE}" ]; then
    if [ -f "${CONFIG_DIR}/default_address.txt" ]; then
        grep -o 'tcp[A-Za-z0-9_-]\+' "${CONFIG_DIR}/default_address.txt" | head -1 > "${SAVED_ADDR_FILE}"
    fi
fi

echo "[3/4] Capturing sandbox-local egress proxy variables and installing systemd unit..."
# NEVER copy proxy settings from another VM: local proxies carry rotating auth credentials!
PROXY_ENV_LINES=""
for var in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
    if [ -n "${!var:-}" ]; then
        PROXY_ENV_LINES="${PROXY_ENV_LINES}Environment=\"${var}=${!var}\"\n"
    fi
done

# Authorized keys for developer access
if [ -z "${TAILCAT_AUTHORIZED_KEYS:-}" ]; then
    echo "ERROR: TAILCAT_AUTHORIZED_KEYS environment variable is not set." >&2
    echo "Export your public key before running:" >&2
    echo "  export TAILCAT_AUTHORIZED_KEYS=\"ssh-ed25519 AAAAC3... developer@host\"" >&2
    exit 1
fi
AUTH_KEYS="${TAILCAT_AUTHORIZED_KEYS}"

SERVICE_FILE="/etc/systemd/system/tailcat.service"
sudo bash -c "cat << EOF > ${SERVICE_FILE}
[Unit]
Description=Tailcat Persistent Ingress Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=${HOME_DIR}
$(printf '%b' "${PROXY_ENV_LINES}")ExecStart=${TAILCAT_BIN} serve --key=default --files=${HOME_DIR}:rw --ssh-authorized-keys=\"${AUTH_KEYS}\" ssh,files
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable tailcat.service
sudo systemctl restart tailcat.service

echo "[4/4] Verifying canonical address resolution..."
sleep 2

# Resolve and verify byte-identical matches
SAVED_ADDR=$(cat "${SAVED_ADDR_FILE}")
RESOLVED_SAVED=$("${TAILCAT_BIN}" resolve "${SAVED_ADDR}")
echo "${RESOLVED_SAVED}" > "${SAVED_RESOLVED_FILE}"

RUNTIME_ADDR=$(sudo journalctl -u tailcat.service -n 25 --no-pager | grep -o 'tcp[A-Za-z0-9_-]\+' | tail -1 || true)
if [ -n "${RUNTIME_ADDR}" ]; then
    RESOLVED_RUNTIME=$("${TAILCAT_BIN}" resolve "${RUNTIME_ADDR}")
    if [ "${RESOLVED_RUNTIME}" = "${RESOLVED_SAVED}" ]; then
        echo "[VERIFIED] Runtime address matches saved key byte-identically!"
    else
        echo "[WARNING] Address drift detected between saved and runtime!"
        echo "  Saved resolved:   ${RESOLVED_SAVED}"
        echo "  Runtime resolved: ${RESOLVED_RUNTIME}"
    fi
fi

echo "=============================================================================="
echo " TAILCAT REBOOT-PERSISTENT INGRESS READY"
echo "=============================================================================="
echo "Short Address:      ${SAVED_ADDR}"
echo "Canonical Resolved: ${RESOLVED_SAVED}"
echo "Connect command:"
echo "  tailcat ssh root@${SAVED_ADDR}"
echo "=============================================================================="
