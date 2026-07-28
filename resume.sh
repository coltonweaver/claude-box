#!/usr/bin/env bash
# Resume the claude-box droplet from its pause snapshot. The restored droplet
# rejoins the tailnet as the same tagged node automatically (the node key
# lives on the snapshotted disk), and the deny-all-inbound firewall is
# reattached at DO's edge.
#
# Prereq: doctl auth init (with a DO API token)
# Usage:  ./resume.sh [snapshot-name]   (defaults to newest claude-box-paused-*)
set -euo pipefail

NAME="${NAME:-claude-box}"
REGION="${REGION:-nyc3}"          # must match the snapshot's region
SIZE="${SIZE:-s-1vcpu-2gb}"       # disk must be >= snapshot min disk (50GB)

if ! doctl account get >/dev/null 2>&1; then
  echo "error: doctl is not authenticated — run: doctl auth init" >&2
  exit 1
fi
if doctl compute droplet get "$NAME" >/dev/null 2>&1; then
  echo "error: droplet '$NAME' already exists" >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  snapshot_name="$1"
else
  snapshot_name="$(doctl compute snapshot list --format Name --no-header \
    | grep "^${NAME}-paused-" | sort | tail -1)"
fi
if [[ -z "$snapshot_name" ]]; then
  echo "error: no ${NAME}-paused-* snapshot found" >&2
  exit 1
fi
snapshot_id="$(doctl compute snapshot list --format ID,Name --no-header \
  | awk -v n="$snapshot_name" '$2==n{print $1}')"

echo "==> Creating $NAME from snapshot $snapshot_name ($snapshot_id)…"
doctl compute droplet create "$NAME" \
  --region "$REGION" --size "$SIZE" --image "$snapshot_id" --wait

droplet_id="$(doctl compute droplet get "$NAME" --format ID --no-header)"

echo "==> Reattaching deny-all-inbound firewall…"
fw_id="$(doctl compute firewall list --format ID,Name --no-header \
  | awk '$2=="tailnet-only"{print $1}')"
if [[ -z "$fw_id" ]]; then
  doctl compute firewall create --name tailnet-only \
    --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
    --droplet-ids "$droplet_id"
else
  doctl compute firewall add-droplets "$fw_id" --droplet-ids "$droplet_id"
fi

echo
echo "==> Done. Within ~1-2 minutes the node should be back in: tailscale status"
echo "    Then:  ssh $NAME  and  tmux attach -t main"
