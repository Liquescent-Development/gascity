# Tutorial 2 — The superpowers factory

*You know the superpowers plugin from Claude Code. Now run the same
methodology as a software factory: durable, parallel, and out of your
session.*

**Audience:** you've used Claude Code with the
[superpowers](https://github.com/obra/superpowers) plugin — brainstorming
before building, writing plans, strict TDD, requesting code review — and
you've finished [Tutorial 1](01-your-first-fleet.md) (a running city with the
`greetbot` rig).

**Time:** 45–60 minutes, most of it watching agents work.

> **Prefer a guided ride?** `/opt/gascity-tutorials/02-superpowers-factory.sh`
> walks these steps interactively.

---

## From skills to structure

In Claude Code, superpowers works by *persuasion*: skill files tell the model
"you MUST brainstorm before building, you MUST write the failing test first"
— and a strong model mostly complies. But the discipline lives in the model's
short-term intentions. Nothing *structural* stops a session from skipping the
failing-test step when context runs long.

The superpowers **pack** turns that discipline into graph structure. Each
skill you know becomes steps and gates in a formula the orchestrator
enforces:

| Superpowers skill (Claude Code) | In the pack |
| --- | --- |
| `brainstorming` | A **requirements phase with two hard gates**: the design must pass approval, then the written spec must pass approval — fail loops back, never falls through |
| `writing-plans` | A planning step run by a dedicated `writing-plans` agent, with an artifact-validity check (3 attempts) |
| `subagent-driven-development` | The orchestrator itself: tasks fan out to worker sessions as a **convoy drain** |
| `test-driven-development` | Per-task step beads — write failing test → verify it fails → implement → verify it passes — that **cannot be skipped**, because they're dependency-gated beads, not intentions |
| `requesting-code-review` / `receiving-code-review` | A per-task double review (spec-compliance + code-quality) plus a final review **fan-out** with a gap-analysis lane, looping until the verdict is `done` |
| `finishing-a-development-branch` | A `finisher` agent runs the finalize step; publish only pushes / opens a PR if you said so |
| `using-git-worktrees` | `drain_policy=separate`: each task in its own worktree and session, in parallel |

Same skills — the pack literally vendors the upstream skill files as source
material — but the *model choosing to follow a skill* is replaced by *the
graph only offering the next legal step*. And because each step is a bead,
the whole pipeline survives crashes, restarts, and your laptop lid.

## Step 0 — Where packs come from

A **pack** is a directory with a `pack.toml`: agents, formulas, orders, and
their support files. Your city is already a pack (look at
`~/cities/tutorial/pack.toml` — it has `[imports.*]` entries from `gc init`).
Importing a shared pack makes its agents and formulas read exactly like ones
you declared locally, namespaced by the import binding.

The public catalog lives at
[github.com/gastownhall/gascity-packs](https://github.com/gastownhall/gascity-packs):
five interchangeable build methodologies (`gascity`, `bmad`,
`compound-engineering`, `superpowers`, `gstack`) that all expose the same
launch variables — switching methodology is a one-word change — plus support
packs (Slack integration, PR pipelines). You're importing `superpowers`.

## Step 1 — Import the pack

From the city directory:

```bash
cd ~/cities/tutorial
gc import add https://github.com/gastownhall/gascity-packs/tree/main/superpowers
```

This resolves the source, locks it in `packs.lock`, installs it to the cache,
and writes a durable `[imports.superpowers]` entry into your `pack.toml` —
look:

```bash
grep -A2 'imports.superpowers' pack.toml
```

The superpowers pack's own `pack.toml` is four lines plus one import — it
pulls in the base `gascity` pack (the `build-base` workflow contract and the
`gc.*` operator agents) transitively. Packs compose.

## Step 2 — Give the rig its worker roles

The build formula routes steps to worker roles (`gc.run-operator`,
`gc.task-decomposer`, and the superpowers agents). Those are **rig-scoped**:
each rig that runs work needs the roles sub-pack. Edit
`~/cities/tutorial/city.toml` — find your `[[rigs]]` entry and add the import
below it:

```toml
[[rigs]]
name = "greetbot"

[rigs.imports.gc]
source = "https://github.com/gastownhall/gascity-packs.git//gascity/roles"
```

Then resolve and verify:

```bash
gc import install             # resolve imports, write/repair packs.lock, fill the cache
gc import check               # read-only: anything missing or stale?
gc config show --validate     # the composed city parses clean
```

> ✅ **Checkpoint:** `gc import check` is clean, and `gc formula list` now
> shows the `superpowers-*` family. Inspect the big one:
>
> ```bash
> gc formula show superpowers-build
> ```
>
> That's the whole factory: prepare → requirements (two approval gates) →
> plan → plan-review → decompose → implement (convoy drain) → review fan-out
> → finalize → publish. Note how much structure arrived from one `import add`
> — and that **zero** of it is hardcoded in Gas City: it's all configuration
> you could read, fork, or replace.

Nine agents came with it too — `superpowers.brainstorming`,
`superpowers.implementer`, `superpowers.code-reviewer`,
`superpowers.finisher`, and friends. Import binding names qualify agent
names, so they can never collide with yours.

## Step 3 — Run the factory

Give it a real feature on greetbot. Create the work bead **from the rig
directory** (so it lands in the rig's namespace), then sling the formula at
it. `artifact_root` — where the factory writes its design, spec, plan, and
reports inside the rig — is the only required variable:

```bash
cd ~/projects/greetbot
gc bd create "Add a --shout flag to greetbot that uppercases the greeting and adds exclamation marks, with tests"
# note the printed bead ID, then:
gc sling gc.run-operator <bead-id> --on superpowers-build \
  --var artifact_root=plans/shout-flag/build
```

(If `gc.run-operator` doesn't resolve from the rig, use the rig-qualified
name: `greetbot/gc.run-operator`.)

Defaults for a first run: brainstorming approval runs autonomously, review
verdicts come from reviewer agents, and nothing is pushed anywhere —
`push=false`, `open_pr=false`, so the factory's output stays local branches
and artifacts you can inspect.

## Step 4 — Watch a methodology execute

Same observation tools as Tutorial 1, much bigger show. In a second terminal
(`docker compose exec gascity bash`):

```bash
gc events --follow
```

And from anywhere:

```bash
gc session list                     # brainstormer, then planner, then implementers...
gc bd list                          # the phase beads marching open → closed
gc bd show <bead-id> --watch        # your original bead, now the workflow's subject
```

Plus the dashboard (http://localhost:8372/). What to look for, phase by
phase:

1. **Requirements** — the `superpowers.brainstorming` agent works your one
   sentence into a design, then a written spec. Watch the artifacts appear:
   `ls ~/projects/greetbot/plans/shout-flag/build/`. If a gate check fails,
   you'll see the loop-back in the events — the graph refusing to fall
   through, exactly what the plugin could only *ask* the model to do.
2. **Plan and plan-review** — `superpowers.writing-plans` writes,
   `superpowers.plan-reviewer` reviews, a validity check gates.
3. **Decompose** — `gc.task-decomposer` turns the plan into task beads
   grouped in a **convoy**.
4. **Implement** — the drain: tasks fan out to `superpowers.implementer`
   sessions. Inside each task, the TDD steps run in their forced order.
   Watch `git -C ~/projects/greetbot branch -a` and the session count.
5. **Review** — two review lanes fan out (code review + gap analysis), fan
   back in, and loop until the verdict is `done`.
6. **Finalize** — `superpowers.finisher` wraps up; a final report lands under
   the artifact root.

> ✅ **Checkpoint:** the workflow root closes; `plans/shout-flag/build/`
> contains the design, spec, plan, decomposition, review reports, and final
> report; the rig has a branch where `python3 -m greetbot --lang English
> --name Ada --shout` shouts, with tests. Review and merge it yourself — the
> factory didn't push because you didn't say `push=true`.

## Step 5 — Dial the knobs

Everything you'd configure in the plugin has a launch variable here — same
run, different `--var`s:

| Variable | Default | What it changes |
| --- | --- | --- |
| `artifact_root` | *(required)* | Where design/spec/plan/report artifacts land in the rig |
| `brainstorming_approval_mode` | `autonomous` | `interactive` makes the design and spec gates wait for **you** — the plugin's "check in with your human partner", now a hard gate |
| `interaction_mode` | `interactive` | `autonomous` / `headless` for unattended runs |
| `review_mode` | `agent` | `report` (findings only) or `interactive` |
| `drain_policy` | `separate` | Per-task worktrees + parallel sessions; `same-session` runs tasks through one lane — right for small changes |
| `push` / `open_pr` | `false` | Let the publish phase push the branch / open a PR |
| `max_iterations` | `10` | Budget for review/fix loops |

The autonomous extreme, for flavor — one command, walk away, come back to a
PR:

```bash
gc sling gc.run-operator <bead-id> --on superpowers-build \
  --var artifact_root=plans/some-feature/build \
  --var interaction_mode=autonomous --var push=true --var open_pr=true
```

Want to inject project-specific rules without forking the pack? Shadow a step
body: create `assets/workflows/superpowers-build/plan.md` in your city and it
replaces the pack's planning prompt — prompt-only override, no graph change.

## Where you are now

You've consumed a pack: someone else's complete methodology — nine agents,
twelve formulas, the skills you already trusted — imported with one command
and run with one sling. Two ideas to take with you:

- **The methodology is configuration.** Swap `superpowers-build` for
  `bmad-build` or `compound-build` (import the pack, same variables) and the
  same engine becomes a different factory. Nothing about Gas City itself
  changed — that's the zero-hardcoded-roles principle doing its job.
- **Structure beats persuasion at scale.** The plugin asks a model to be
  disciplined; the pack makes discipline the only path through the graph.
  As models get stronger, the prompts inside each step get *more* useful —
  the graph never has to get smarter.

### Troubleshooting

- **`gc import add` fails to resolve:** check network from the container
  (`curl -sI https://github.com` ), then retry; `gc import check` shows
  what's missing or stale.
- **Sling can't find the formula:** `gc formula list` — if `superpowers-*`
  is absent, re-run `gc import install` and `gc config show --validate` from
  the city directory.
- **Agent name doesn't resolve:** imported names are qualified — try
  `greetbot/gc.run-operator`, and confirm the rig has the
  `[rigs.imports.gc]` roles entry.
- **A phase looks stuck:** `gc session peek <agent>` to see what it's doing;
  `gc events --since 10m` for the recent story; `gc doctor --fix` for config
  drift.
