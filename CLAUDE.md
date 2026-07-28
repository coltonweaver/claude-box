# claude-box

You are Claude Code running on `claude-box`, a DigitalOcean droplet that is
reachable ONLY over Colton's Tailscale tailnet — all public inbound traffic
is blocked at DigitalOcean's edge. You run as root inside the persistent
tmux session `main`. This is a long-lived session that gets /clear'd
constantly; this file is the durable context that survives each clear.

## How interactions work

- Colton connects remotely (Tailscale SSH / mosh from a Mac or iPhone),
  kicks off work, and often detaches mid-task. Assume he is not watching.
  Keep working to completion instead of pausing on questions; make
  reasonable decisions and note them.
- He frequently reads results on a phone. Lead with the outcome in a short
  paragraph; details after.
- For any task longer than a few minutes, append progress and final results
  to `~/journal/YYYY-MM-DD.md` as you go, so he can catch up after
  reattaching even if the scrollback is gone.
- If the tailnet connection drops mid-conversation, nothing is lost — tmux
  keeps this session alive. He will reattach.

## Environment

- Ubuntu 24.04, 1 vCPU / 2 GB, region nyc3. Small box: avoid heavy parallel
  builds or anything memory-hungry.
- Toolbox: Node 22, pnpm, git, gh, tmux, mosh, curl, jq.
- Workspace convention: clone repos under `~/projects/`.
- This machine pauses via snapshot+destroy and resumes from the snapshot:
  disk state survives, RAM does not. Keep anything that matters on disk;
  never treat a running process as the only copy of a result.

## Git / GitHub

- Full push access to Colton's GitHub (`coltonweaver`) via a dedicated SSH
  key on this box; `gh` is authenticated for API operations (PRs, issues,
  repo admin).
- Git identity is configured (Colton Weaver / me@coltonweaver.com). Work on
  branches, commit as you go, and never force-push a default branch.
- Opening PRs, creating repos, or publishing anything public: ask first
  unless the task explicitly says to.

## Constraints

- Do not modify Tailscale or DigitalOcean firewall configuration — the
  sealed networking posture is the security model of this box, and recovery
  requires break-glass access from Colton's Mac.
- Credentials live on this disk (GitHub SSH key, gh OAuth token). Never
  print, copy, or move them.
- Do not build against or call Monarch Money's private API — this was
  removed from the box deliberately (ToS decision).
- Keep this file current: when the environment materially changes (new
  tool, new convention, new constraint), update it — it is the only memory
  that survives /clear.
