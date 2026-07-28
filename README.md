# claude-box

A DigitalOcean droplet on the tailnet, publicly unreachable, running Claude
Code in tmux.

## One-time setup

1. **Tailscale ACLs** — either paste [tailscale-acl.jsonc](tailscale-acl.jsonc)
   into <https://login.tailscale.com/admin/acls>, or push via API: create an
   API access token at <https://login.tailscale.com/admin/settings/keys>, then
   `TS_API_KEY=tskey-api-xxxx ./push-acl.sh`.
2. **Tailscale auth key** — at
   <https://login.tailscale.com/admin/settings/keys> generate an auth key:
   *single-use*, *pre-approved*, tag `tag:server`.
3. **doctl auth** — create an API token (full access) at
   <https://cloud.digitalocean.com/account/api/tokens>, then run
   `doctl auth init` and paste it when prompted.

## Provision

```bash
TS_AUTHKEY=tskey-auth-xxxx ./provision.sh
```

Defaults: `nyc3`, `s-1vcpu-2gb`, Ubuntu 24.04. Override with env vars
(`REGION=sfo3`, `SIZE=...`, `NAME=...`).

## Verify

```bash
tailscale status            # claude-box appears within ~2 min of boot
ssh claude-box              # Tailscale SSH — no key setup
nc -zv -G 3 <public-ip> 22  # should TIME OUT (inbound blocked at DO edge)
```

## Move-in (on the droplet)

Claude Code is installed (native installer, ~/.local/bin, on PATH).
Remaining one-time step:

```bash
tmux new -s main
claude   # authenticate with your Anthropic account (browser URL flow)
```

## Break-glass access

If Tailscale on the box ever breaks, the DO web console is the way in --
but it is NOT out-of-band: it SSHes to the droplet on port 22, which the
firewall blocks.

Step zero: the DO API token was revoked after provisioning, so mint a new
one at <https://cloud.digitalocean.com/account/api/tokens> and run
`doctl auth init` first. Then temporarily open port 22:

```bash
FW_ID=$(doctl compute firewall list --format ID,Name --no-header | awk '$2=="tailnet-only"{print $1}')
doctl compute firewall add-rules "$FW_ID" --inbound-rules "protocol:tcp,ports:22,address:0.0.0.0/0,address:::/0"
```

Then use Droplet page -> Access -> Launch Droplet Console (root password is
in the password manager). Re-seal when done:

```bash
doctl compute firewall remove-rules "$FW_ID" --inbound-rules "protocol:tcp,ports:22,address:0.0.0.0/0,address:::/0"
```

## Day-to-day

From Mac or iPhone (Termius/Blink + Tailscale app):

```bash
ssh claude-box        # or: mosh claude-box
tmux attach -t main
```
