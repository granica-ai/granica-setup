#!/bin/bash
# One-time, in-place Teleport SSH-node enrollment for an EXISTING Granica
# admin-server, so a CP operator can `tsh ssh` into it via the CP Teleport proxy.
#
# New deployments get this automatically via user_data (cp_teleport_enabled=true
# in the tfvars). This script is the UPGRADE path for admin-servers that already
# exist: it does exactly what user_data would do, without recreating the VM and
# without touching the data-plane cluster. It is idempotent — safe to re-run.
#
# Run it ON the admin-server as root, e.g. via SSM:
#   aws ssm send-command --instance-ids <admin-id> --document-name AWS-RunShellScript \
#     --parameters commands='CP_PROXY_ADDR=... CP_CA_PIN=... CP_NODE_TOKEN=... \
#       CUSTOMER_ID=... bash /path/to/enroll_teleport_node.sh'
#
# Required env vars (same three values the CP hands out for hybrid onboarding):
#   CP_PROXY_ADDR   CP Teleport proxy host:443 (e.g. cp.<customer>.aws.granica.ai:443)
#   CP_CA_PIN       CP cluster CA pin (sha256:...)
#   CP_NODE_TOKEN   node-role join token minted on the CP (tctl tokens add --type=node)
#   CUSTOMER_ID     deployment/customer id (used for nodename + labels)
# Optional:
#   TELEPORT_VERSION (default 18.7.4 — match the CP), TELEPORT_EDITION (default oss),
#   AWS_REGION (label only)
set -euo pipefail

: "${CP_PROXY_ADDR:?CP_PROXY_ADDR is required}"
: "${CP_CA_PIN:?CP_CA_PIN is required}"
: "${CP_NODE_TOKEN:?CP_NODE_TOKEN is required}"
: "${CUSTOMER_ID:?CUSTOMER_ID is required}"
TELEPORT_VERSION="${TELEPORT_VERSION:-18.7.4}"
TELEPORT_EDITION="${TELEPORT_EDITION:-oss}"
AWS_REGION="${AWS_REGION:-unknown}"

if [ "$(id -u)" -ne 0 ]; then echo "Must run as root (sudo)."; exit 1; fi

echo "[enroll] reachability check -> https://$CP_PROXY_ADDR"
curl -sk --max-time 12 "https://$CP_PROXY_ADDR/webapi/find" >/dev/null \
  || { echo "[enroll] ERROR: cannot reach the CP proxy at $CP_PROXY_ADDR"; exit 1; }

if ! command -v teleport >/dev/null 2>&1; then
  echo "[enroll] installing Teleport $TELEPORT_VERSION ($TELEPORT_EDITION)"
  curl -fsSL https://cdn.teleport.dev/install.sh | bash -s "$TELEPORT_VERSION" "$TELEPORT_EDITION"
fi
teleport version | head -1

echo "[enroll] writing /etc/teleport.yaml"
mkdir -p /var/lib/teleport
cat > /etc/teleport.yaml <<YAML
version: v3
teleport:
  nodename: granica-admin-${CUSTOMER_ID}
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
  auth_token: ${CP_NODE_TOKEN}
  ca_pin: "${CP_CA_PIN}"
  proxy_server: ${CP_PROXY_ADDR}

ssh_service:
  enabled: true
  labels:
    customer: ${CUSTOMER_ID}
    plane: data
    role: admin-server
    region: ${AWS_REGION}

auth_service:
  enabled: false

proxy_service:
  enabled: false
YAML
chmod 0640 /etc/teleport.yaml

echo "[enroll] starting Teleport"
systemctl daemon-reload
systemctl enable teleport >/dev/null 2>&1 || true
systemctl restart teleport
sleep 5
echo "[enroll] teleport active=$(systemctl is-active teleport)"
echo "[enroll] done — verify on the CP with: tctl nodes ls  (look for granica-admin-${CUSTOMER_ID})"
