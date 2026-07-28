#!/usr/bin/env bash
# Provision the claude-box droplet on DigitalOcean, joined to the tailnet,
# with all public inbound traffic blocked at DO's edge.
#
# Prereqs:
#   1. doctl auth init          (with a DO API token you created)
#   2. TS_AUTHKEY=tskey-auth-…  (pre-approved, tagged tag:server, from
#                                https://login.tailscale.com/admin/settings/keys)
# Usage:
#   TS_AUTHKEY=tskey-auth-xxxx ./provision.sh
set -euo pipefail

NAME="${NAME:-claude-box}"
REGION="${REGION:-nyc3}"          # sfo3 if you're West Coast
SIZE="${SIZE:-s-1vcpu-2gb}"       # doctl compute size list to browse
IMAGE="${IMAGE:-ubuntu-24-04-x64}"

if [[ -z "${TS_AUTHKEY:-}" ]]; then
  echo "error: set TS_AUTHKEY to a pre-approved Tailscale auth key (tag:server)" >&2
  exit 1
fi
if ! doctl account get >/dev/null 2>&1; then
  echo "error: doctl is not authenticated — run: doctl auth init" >&2
  exit 1
fi
if doctl compute droplet get "$NAME" >/dev/null 2>&1; then
  echo "error: droplet '$NAME' already exists" >&2
  exit 1
fi

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT
sed "s|\${TS_AUTHKEY}|${TS_AUTHKEY}|" cloud-init.yaml > "$rendered"

# cloud-init silently discards the whole config if user-data contains
# non-ASCII bytes (learned the hard way via an em dash in a comment).
if ! iconv -f ascii -t ascii "$rendered" >/dev/null 2>&1; then
  echo "error: rendered cloud-init contains non-ASCII bytes; offending lines:" >&2
  LC_ALL=C grep -n '[^[:print:][:space:]]' "$rendered" >&2 || true
  exit 1
fi

echo "==> Creating droplet $NAME ($SIZE, $REGION)…"
doctl compute droplet create "$NAME" \
  --region "$REGION" --size "$SIZE" --image "$IMAGE" \
  --user-data-file "$rendered" --wait

droplet_id="$(doctl compute droplet get "$NAME" --format ID --no-header)"
public_ip="$(doctl compute droplet get "$NAME" --format PublicIPv4 --no-header)"

echo "==> Attaching deny-all-inbound firewall…"
if ! doctl compute firewall list --format Name --no-header | grep -qx "tailnet-only"; then
  doctl compute firewall create --name tailnet-only \
    --outbound-rules "protocol:tcp,ports:all,address:0.0.0.0/0,address:::/0 protocol:udp,ports:all,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
    --droplet-ids "$droplet_id"
else
  fw_id="$(doctl compute firewall list --format ID,Name --no-header | awk '$2=="tailnet-only"{print $1}')"
  doctl compute firewall add-droplets "$fw_id" --droplet-ids "$droplet_id"
fi

echo
echo "==> Done. Droplet $NAME is up (public IP $public_ip, inbound fully blocked)."
echo "    Within ~2 minutes it should appear in: tailscale status"
echo "    Then:  ssh $NAME   (Tailscale SSH, no keys needed)"
echo "    Verify lockdown: nc -zv -G 3 $public_ip 22   # should time out"
