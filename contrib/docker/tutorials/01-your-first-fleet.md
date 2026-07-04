# Tutorial 1 — Your first fleet

*From one Claude to many: build a small program with a team of agents working
in parallel, and watch every move they make.*

**Audience:** you've used Claude Code — one agent, one terminal, one
conversation — and you want to see what changes when an orchestrator runs
*many* agents for you.

**Time:** 30–45 minutes. **Prerequisite:** the tutorial container is running
(see `contrib/docker/README.md`) and you have first-party Claude Code
authentication — run `claude` once inside the container and log in, or set
`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`. (An `ANTHROPIC_API_KEY`
does not satisfy gc's provider readiness check.)

> **Prefer a guided ride?** `/opt/gascity-tutorials/01-your-first-fleet.sh`
> runs this same tutorial interactively — it explains each step, shows you
> every command before running it, and waits for you between steps. This
> document is the self-paced version of the same material.

---

## What you'll build

Not `print("hello world")` — one agent needs no fleet for that. You'll build
**greetbot**: a small Python CLI that prints a time-of-day-aware greeting, in
one of five languages, inside an ASCII-art banner, with a test suite. Tiny,
but it has genuinely *independent parts*:

- a greeting engine (`greetings.py`)
- a banner renderer (`banner.py`)
- a test suite written against the contracts, not the code

Independent parts are exactly what multi-agent dispatch is for: after one
scaffolding step, **three agents build those three parts at the same time**,
and the orchestrator holds back the integration step until all of them finish.
You'll watch that happen live.

## The mental model, in five minutes

In Claude Code, you are the orchestrator: you decide what to ask, you watch
the one session, you carry the state in your head, and when you close the
laptop the work stops. Gas City moves each of those jobs into durable
machinery, composed from six primitives:

| You know (Claude Code) | Gas City primitive | What changed |
| --- | --- | --- |
| Your `claude` session + CLAUDE.md | **Agent** (WHO) — a configured worker: prompt template, provider, scope | Defined in config, so you can have many; a running agent is a *session* the platform starts, stops, and observes |
| Your mental todo list | **Bead** (WHAT) — one unit of work with an ID and status | Durable in a store; work survives any session crash |
| The plan in your head | **Formula** (HOW) — a written-down method: steps + dependencies in a TOML file | The orchestrator runs it as a graph, fanning ready steps out to agents *outside your session* |
| Your repo | **Rig** (WHERE) — a project registered with the city | Gets its own bead namespace and agent scope |
| Your settings + CLAUDE.md | **Pack** (CONFIGURES) — declares agents, formulas, orders | Your city *is* the local pack; it can import shared packs (Tutorial 2) |
| Scrollback | **Event** (OBSERVE) — notifications fired by activity | A replayable stream humans *and* agents watch |

One sentence to keep: **a formula operates over beads, fanning work out to
agents that execute in a rig, while events fire so you can watch.** The
orchestrator — role-agnostic machinery, not an agent — drives the graph:
dispatching ready steps, gating blocked ones, retrying failures.

## Step 0 — Check the environment

Inside the container:

```bash
gc version && claude --version && bd version && dolt version && tmux -V
```

> ✅ **Checkpoint:** five version lines, no errors. If `gc init` reports
> "needs authentication" later, run `claude` once and log in (credentials
> persist in the volume), or restart the container with
> `CLAUDE_CODE_OAUTH_TOKEN` set from `claude setup-token`.

## Step 1 — Found a city

A **city** is a directory: config, runtime state, and the work ledger for one
deployment.

```bash
gc init ~/cities/tutorial --default-provider claude
cd ~/cities/tutorial
```

`gc init` bootstraps the directory, initializes the bead store (a managed
Dolt database under `.beads/` — you never touch it directly), registers the
city with the machine-wide supervisor, and starts it.

Look at what it wrote:

```bash
cat city.toml    # deployment: providers, daemon settings
cat pack.toml    # definition: the city IS a pack; note the [imports.*]
gc status        # orchestrator, agents, API URL
```

Two things worth noticing in `city.toml`:

```toml
[workspace]
provider = "claude"          # default harness for every agent

[providers.claude]
base = "builtin:claude"      # the builtin Claude Code preset: launches the
                             # `claude` CLI with sensible flags
```

And open the **dashboard** from your host browser: **http://localhost:8372/**
— agents, beads, formula runs, and a live event feed, all in one place. Keep
this tab open for the whole tutorial. (If it doesn't load, start the
machine-wide supervisor: `gc supervisor start`.)

> ✅ **Checkpoint:** `gc status` shows the city running; the dashboard loads.

## Step 2 — Register a rig

Work happens in a **rig** — an external project, usually a git repo. Create
one and register it:

```bash
mkdir -p ~/projects/greetbot
git -C ~/projects/greetbot init -b main
cd ~/cities/tutorial            # gc rig add resolves the city from the cwd
gc rig add ~/projects/greetbot
gc rig list
```

> ✅ **Checkpoint:** `gc rig list` shows `greetbot` with a bead-ID prefix
> (something like `gr`). Every bead created for this rig carries that prefix
> — that's how one store keeps many projects isolated.

## Step 3 — Sling one bead (the part you already know)

Before the fleet, do the familiar thing once: give one agent one task.
**Sling** is Gas City's dispatch verb — it creates a bead *and* routes it to
an agent in one motion:

```bash
cd ~/projects/greetbot
gc sling greetbot/claude "Create a README.md for greetbot: a CLI that prints multilingual, time-of-day-aware greetings in an ASCII banner. Describe the planned modules: greetings.py, banner.py, cli.py. Commit it."
```

Note the output: `Created <bead-id>` — copy that ID. Now watch it three ways:

```bash
gc bd show <bead-id> --watch      # the bead's live status: open → in_progress → closed
gc session list                   # a session spun up for greetbot/claude
gc session peek greetbot/claude   # the agent's actual terminal, last few lines
```

(`--watch` streams forever by design — when the status shows `CLOSED`, the
agent is done; press Ctrl-C to move on.)

This is the whole Claude Code experience, re-based on durable machinery: the
task is a bead in a store, the session is observable from outside, and if the
agent crashed mid-task the bead would stay open for the next agent. When the
bead closes, check the rig — `README.md` exists and is committed.

> ✅ **Checkpoint:** the bead reaches `closed`; `git -C ~/projects/greetbot log
> --oneline` shows the agent's commit. Auth works, dispatch works — time for
> the fleet.

## Step 4 — Configure a worker pool

One named agent is a person. For fan-out you want a **pool**: one agent
definition the orchestrator can scale into several identical sessions sharing
a queue.

```bash
cd ~/cities/tutorial
gc agent add --name worker
```

Point it at the rig and give it a pool range — edit
`agents/worker/agent.toml` to exactly this:

```toml
dir = "greetbot"            # rig-scoped: works in ~/projects/greetbot
min_active_sessions = 0     # scale to zero when idle
max_active_sessions = 3     # up to three concurrent sessions
```

And give it a behavioral spec — the prompt template *is* the role. Write
`agents/worker/prompt.template.md`:

```markdown
# Worker

You are a Gas City worker on the greetbot project. When work lands on your
hook, execute exactly what the step describes — no more, no less. Other
workers are building sibling modules concurrently, so stay inside the files
your step names. Use only the Python standard library. Commit when your step
is done, then close your bead.
```

That prompt line — "if work lands on your hook, run it" — is the entire
coordination protocol. No worker knows about the others; the dependency graph
does the coordinating.

> ✅ **Checkpoint:** `gc status` now lists `greetbot/worker` (0 running — the
> pool scales up only when work arrives).

## Step 5 — Write the formula

A **formula** is the method, written down: steps and their `needs` edges.
Save this as `~/cities/tutorial/formulas/greetbot.toml`:

```toml
formula = "greetbot"
description = "Build the greetbot CLI with parallel workers"

[requires]
formula_compiler = ">=2.0.0"   # v2: the orchestrator runs this as a graph

[vars]
languages = "English, Spanish, French, German, Japanese"

[[steps]]
id = "scaffold"
title = "Scaffold the greetbot package"
description = """
In the greetbot repo, create the package skeleton: greetbot/__init__.py,
empty greetbot/greetings.py, empty greetbot/banner.py, empty greetbot/cli.py,
greetbot/__main__.py that calls cli.main(), and a tests/ directory.
Commit with message 'scaffold greetbot package'.
"""

[[steps]]
id = "greetings"
title = "Implement the greeting engine"
needs = ["scaffold"]
description = """
Implement greetbot/greetings.py only. Provide greeting(language, hour) -> str
returning a greeting in the given language ({{languages}}), where hour
(0-23) selects morning/afternoon/evening phrasing. Pure function, standard
library only, raise ValueError on unknown language. Commit.
"""

[[steps]]
id = "banner"
title = "Implement the ASCII banner renderer"
needs = ["scaffold"]
description = """
Implement greetbot/banner.py only. Provide frame(text) -> str that returns
the text wrapped in a decorative ASCII box (handle multi-line text and
padding). Standard library only. Commit.
"""

[[steps]]
id = "tests"
title = "Write the test suite"
needs = ["scaffold"]
description = """
Write tests/test_greetings.py and tests/test_banner.py using unittest,
against the contracts stated in this formula (greeting(language, hour),
frame(text)) — do NOT read or wait for the implementations; test the
contract. Include ValueError cases. Commit.
"""

[[steps]]
id = "cli"
title = "Wire the CLI"
needs = ["greetings", "banner"]
description = """
Implement greetbot/cli.py: main() parses --lang (default English) and --name,
composes banner.frame(greetings.greeting(...) + ', ' + name + '!') using the
current hour, and prints it. Commit.
"""

[[steps]]
id = "verify"
title = "Run the tests and fix failures"
needs = ["cli", "tests"]
description = """
Run: python3 -m unittest discover -s tests -v
Fix any failures (in implementation or tests — judge which is wrong against
the contracts in this formula). Then run: python3 -m greetbot --lang Spanish
--name Ada and include its output in your final report. Commit any fixes.
"""
```

Read the shape, not the prose: `greetings`, `banner`, and `tests` all need
only `scaffold` — **nothing orders them relative to each other, so the
orchestrator is free to run all three at once.** `cli` gates on two of them;
`verify` gates on everything.

Compile it and look at the graph before running anything:

```bash
gc formula show greetbot
```

> ✅ **Checkpoint:** seven steps — your six plus a `workflow-finalize` control
> step the compiler appended. The `[needs: ...]` annotations match the fan-out
> you wrote. (Steps with no `needs` between them = parallel.)

## Step 6 — Light the fuse

Open a **second terminal** into the container first, for the event stream:

```bash
# on your host
docker compose exec gascity bash
# inside
gc events --follow
```

Back in the first terminal — sling the formula at the worker pool. Run it
from the rig so the beads land in the rig's namespace:

```bash
cd ~/projects/greetbot
gc sling greetbot/worker greetbot --formula --nudge
```

One command: compile the formula, materialize root + steps as beads, route
the workflow to the pool, poke it awake.

## Step 7 — Watch the fan-out

This is the moment the tutorial is for. `scaffold` runs first (everything
else is blocked on it). The instant it closes, **three steps become ready at
once** and the pool scales to meet them. Watch from several angles:

```bash
gc session list        # run repeatedly: 1 worker session → then 3, concurrently
gc bd list             # step beads: in_progress in parallel, blocked ones invisible-to-agents
gc bd show <root-id> --watch    # root bead from the sling output; closes when all steps do
gc session peek greetbot/worker # what a worker is typing right now
```

In the second terminal, `gc events --follow` narrates everything:
`bead.created` for each step, sessions waking, `bead.closed` as steps finish.
And the dashboard (http://localhost:8372/) shows the same story graphically —
the formula run's step states, the session count breathing up and down.

Want to look over an agent's shoulder in full? Sessions are real tmux
sessions:

```bash
gc session attach greetbot/worker    # detach with Ctrl-b then d — never Ctrl-c
```

> ✅ **Checkpoint:** at peak you saw **multiple sessions working
> simultaneously** on `greetings`, `banner`, and `tests`; `cli` stayed
> blocked until its two `needs` closed; `verify` ran last; then the root bead
> closed. No step needed you.

## Step 8 — Inspect the result

```bash
cd ~/projects/greetbot
git log --oneline            # one commit per step, from different sessions
python3 -m unittest discover -s tests -v
python3 -m greetbot --lang French --name Ada
```

> ✅ **Checkpoint:** tests pass; an ASCII-boxed French greeting appears. Built
> by a fleet you configured but never once typed code for.

## Step 9 — Shut down (or don't)

```bash
gc stop ~/cities/tutorial
```

Here's the part worth sitting with: stop the city, `docker compose down`,
bring it all back tomorrow — and the beads, the closed steps, the whole
history are still there (`gc start ~/cities/tutorial`, then `gc bd list`).
**Sessions are disposable; the work survives them.** That persistence, not
raw parallelism, is why the system converges: any agent can die at any point
and a fresh one picks up the same open bead.

## Where you are now

You've used all six primitives: a **pack** (your city) declared **agents**, a
**formula** fanned **beads** out to a pool executing in a **rig**, and
**events** let you watch. What you haven't done is import someone *else's*
pack — a whole methodology, prebuilt. That's
[Tutorial 2](02-superpowers-factory.md), and if you use the superpowers
plugin in Claude Code, you already know the methodology in question.

### Troubleshooting

- **`gc doctor --fix`** is the first move for any config complaint (missing
  provider aliases, import drift).
- **Sessions won't start / auth dialog:** run `claude` manually once in the
  container to complete login; check `gc session peek <agent>` to see what
  the session is stuck on.
- **`gc sling` refuses to route:** check you're running it from the rig
  directory (beads are scope-prefixed; a rig's bead can't route to an agent
  reading a different store).
- **Formula won't compile:** `gc formula show greetbot` reports the exact
  error; most common is a typo in a `needs` id.
