#!/usr/bin/env bash
# Push tailscale-acl.jsonc to the tailnet via the Tailscale API.
#
# Prereq: an API access token from
#   https://login.tailscale.com/admin/settings/keys  ("API access tokens")
# Usage:
#   TS_API_KEY=tskey-api-xxxx ./push-acl.sh
set -euo pipefail

ACL_FILE="$(dirname "$0")/tailscale-acl.jsonc"

if [[ -z "${TS_API_KEY:-}" ]]; then
  echo "error: set TS_API_KEY to a Tailscale API access token" >&2
  exit 1
fi

# "-" resolves to the tailnet the token belongs to.
BASE="https://api.tailscale.com/api/v2/tailnet/-/acl"

echo "==> Validating policy…"
validate_out="$(curl -sf -u "${TS_API_KEY}:" \
  -H "Content-Type: application/hujson" \
  --data-binary "@${ACL_FILE}" \
  "${BASE}/validate")"
# /validate returns {"message": ...} on problems, empty-ish JSON when clean.
if echo "$validate_out" | grep -q '"message"'; then
  echo "error: policy failed validation:" >&2
  echo "$validate_out" >&2
  exit 1
fi
echo "    OK"

echo "==> Pushing policy…"
curl -sf -u "${TS_API_KEY}:" \
  -H "Content-Type: application/hujson" \
  --data-binary "@${ACL_FILE}" \
  "$BASE" >/dev/null
echo "    Applied. Review at https://login.tailscale.com/admin/acls"
