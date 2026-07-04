# Gas City in Docker — tutorial environment

One container with everything needed to run Gas City with **Claude Code as
the backing agent**: the `gc` orchestrator (built from this repo's source),
`bd` + `dolt` (the beads work ledger), `tmux`, `jq`, `git`, `flock`, and the
`claude` CLI. Two interactive tutorials are baked in at
`/opt/gascity-tutorials`.

## Quick start

```bash
cd contrib/docker
docker compose up -d --build     # first build compiles gc — takes a few minutes
docker compose exec gascity bash
```

### Authentication (pick one, before running `gc init`)

`gc init` runs a provider readiness check that requires **first-party Claude
Code auth** — a claude.ai login or a `claude setup-token` OAuth token. An
`ANTHROPIC_API_KEY` does **not** satisfy it (the probe classifies API-key
auth as an unsupported configuration for the builtin claude provider).

- **Interactive login (Pro/Max subscription):** run `claude` once inside the
  container and `/login` with your Claude account — the headless flow prints
  a URL to open in your host browser and a code to paste back. Credentials
  persist in the `gc-home` volume, so this is one-time.
- **OAuth token:** on a host where you're already logged in, run
  `claude setup-token` to mint a long-lived token, then
  `export CLAUDE_CODE_OAUTH_TOKEN=<token>` before `docker compose up` — the
  compose file forwards it into the container.

Subscription usage limits are shared with your interactive Claude Code use,
and formula fan-outs run several sessions concurrently.

Then, inside the container:

```bash
/opt/gascity-tutorials/01-your-first-fleet.sh      # guided, interactive
# or read the self-paced version:
less /opt/gascity-tutorials/01-your-first-fleet.md
```

## The tutorials

| | For someone coming from | You build |
| --- | --- | --- |
| **01 — Your first fleet** | plain Claude Code (one agent, one terminal) | a small CLI, written by a pool of agents working **in parallel** on a formula's fan-out steps, watched live via events, sessions, beads, and the dashboard |
| **02 — The superpowers factory** | Claude Code + the [superpowers plugin](https://github.com/obra/superpowers) | a feature shipped by the [superpowers pack](https://github.com/gastownhall/gascity-packs/tree/main/superpowers) — the same skills you know, converted from persuasion into an enforced build graph (spec gates, per-task TDD, review fan-out) |

Each tutorial exists twice: a `.sh` interactive runner (explains every step,
shows each command before running it) and a `.md` self-paced walkthrough of
identical content. Do them in order — 02 builds on 01's city.

## What's in the box

| Piece | Version | Why |
| --- | --- | --- |
| `gc` | built from your checkout | the Gas City orchestrator + CLI + embedded dashboard |
| `claude` | 2.1.123 (pinned, SHA-verified) | the agent harness `gc` launches for `provider = "claude"` |
| `dolt` | 2.1.7 (`deps.env`) | the beads data plane — every city runs a managed Dolt server |
| `bd` | v1.0.4 (`deps.env`, gastownhall/beads) | the beads CLI: init path and store fallback |
| tmux, jq, git, flock | distro | required runtime tools (tmux is the default session provider) |

All external binaries install through the same SHA-pinned scripts CI and the
`contrib/k8s` images use (`.github/scripts/install-*.sh`). Bump versions with
`--build-arg DOLT_VERSION=... BD_VERSION=... CLAUDE_CODE_VERSION=...`.

## Ports, state, users

- **Dashboard / supervisor API:** http://localhost:8372/ (mapped to loopback
  only). The entrypoint seeds `~/.gc/supervisor.toml` with `bind = "0.0.0.0"`
  + `allow_mutations = true` so the host can reach it; delete that file to
  regenerate.
- **State:** the whole home directory (`/home/gcagent`) is a named volume
  (`gc-home`) — cities and their `.beads/dolt` data, rig working copies under
  `~/projects`, and Claude credentials all survive rebuilds. `docker compose
  down -v` erases everything.
- **Non-root:** everything runs as `gcagent` (passwordless sudo available).
  This is required, not cosmetic — `gc` launches Claude Code with
  `--dangerously-skip-permissions`, which refuses to run as root.

## Relation to `contrib/k8s`

That directory ships a multi-image Kubernetes stack (base/agent/controller)
for production-style fleets. This one is deliberately a single container for
learning and local experiments; it follows the same base conventions
(ubuntu:24.04, pinned installers, non-root `gcagent`).
