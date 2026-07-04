#!/usr/bin/env bash
# Interactive runner for Tutorial 1 — Your first fleet.
# Self-paced version: /opt/gascity-tutorials/01-your-first-fleet.md
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CITY="$HOME/cities/tutorial"
RIG="$HOME/projects/greetbot"

heading "Tutorial 1 — Your first fleet"
say "You'll build 'greetbot' — a multilingual, ASCII-bannered greeting CLI —" \
    "with a team of Claude agents working in parallel, and watch every move." \
    "Each step shows you the command before running it. A second terminal" \
    "(docker compose exec gascity bash) is handy for the watch commands."
pause

heading "Step 0 — Check the environment"
require_bin gc claude bd dolt tmux git python3
run "gc version && claude --version && bd version | head -1 && dolt version && tmux -V"
say "If Claude auth isn't set up yet, run 'claude' once in another terminal" \
    "and log in (or set CLAUDE_CODE_OAUTH_TOKEN from 'claude setup-token')." \
    "gc's readiness check needs first-party Claude Code auth — an" \
    "ANTHROPIC_API_KEY won't satisfy it. Credentials persist in the volume."
pause

heading "Step 1 — Found a city"
say "A city is a directory: config, runtime state, and the durable work" \
    "ledger for one deployment. gc init bootstraps it, initializes the bead" \
    "store, registers it with the supervisor, and starts it."
if [ -d "$CITY" ]; then
  say "City $CITY already exists — reusing it."
  run "gc start '$CITY' || true"
else
  run "gc init '$CITY' --default-provider claude"
fi
run "cd '$CITY' && cat city.toml"
run "gc status"
say "Open the dashboard from your host browser: http://localhost:8372/" \
    "Keep the tab open — you'll watch the fleet there in Step 7." \
    "(If it doesn't load, run: gc supervisor start)"
pause

heading "Step 2 — Register a rig"
say "Work happens in a rig — an external project, usually a git repo," \
    "registered with the city. It gets its own bead-ID namespace."
run "mkdir -p '$RIG' && git -C '$RIG' init -b main"
# gc rig add resolves the city from the current directory — run it from the city.
run "cd '$CITY' && gc rig add '$RIG'"
run "gc rig list"
pause

heading "Step 3 — Sling one bead (the part you already know)"
say "Sling = create a bead AND route it to an agent, one motion. First, the" \
    "familiar single-agent experience — this also proves auth works before" \
    "the big fan-out."
run_capture "cd '$RIG' && gc sling greetbot/claude 'Create a README.md for greetbot: a CLI that prints multilingual, time-of-day-aware greetings in an ASCII banner. Describe the planned modules: greetings.py, banner.py, cli.py. Commit it.'"
BEAD="$(printf '%s\n' "$RUN_OUTPUT" | sed -n 's/^Created \([A-Za-z0-9-]*\).*/\1/p' | head -1)"
if [ -n "$BEAD" ]; then
  say "Captured bead ID: $BEAD"
else
  ask_value "Bead ID from the sling output above (e.g. gr-abc):" BEAD
fi
say "The watch below streams the bead live and never exits on its own —" \
    "when the status line shows CLOSED, the agent is done: press Ctrl-C to" \
    "return to the tutorial."
watch "gc bd show $BEAD --watch"
run "gc session list"
run "gc session peek greetbot/claude || true"
say "When the bead closes: the task was durable state in a store, the" \
    "session observable from outside. Had the agent crashed, the bead would" \
    "have stayed open for the next one."
pause

heading "Step 4 — Configure a worker pool"
say "One named agent is a person. For fan-out you want a pool: one agent" \
    "definition the orchestrator scales into several identical sessions."
run "cd '$CITY' && gc agent add --name worker"
write_file "$CITY/agents/worker/agent.toml" <<'EOF'
dir = "greetbot"            # rig-scoped: works in ~/projects/greetbot
min_active_sessions = 0     # scale to zero when idle
max_active_sessions = 3     # up to three concurrent sessions
EOF
write_file "$CITY/agents/worker/prompt.template.md" <<'EOF'
# Worker

You are a Gas City worker on the greetbot project. When work lands on your
hook, execute exactly what the step describes — no more, no less. Other
workers are building sibling modules concurrently, so stay inside the files
your step names. Use only the Python standard library. Commit when your step
is done, then close your bead.
EOF
say "That prompt is the whole coordination protocol: no worker knows about" \
    "the others — the dependency graph does the coordinating."
pause

heading "Step 5 — Write the formula"
say "A formula is the method, written down: steps + needs edges. greetings," \
    "banner, and tests all need only scaffold — nothing orders them relative" \
    "to each other, so the orchestrator may run all three AT ONCE."
write_file "$CITY/formulas/greetbot.toml" <<'EOF'
formula = "greetbot"
description = "Build the greetbot CLI with parallel workers"

[requires]
formula_compiler = ">=2.0.0"

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
EOF
run "gc formula show greetbot"
say "Seven steps: your six plus the workflow-finalize control step the" \
    "compiler appended. Steps with no needs between them run in parallel."
pause

heading "Step 6 — Light the fuse"
say "Best watched from a second terminal running: gc events --follow" \
    "(docker compose exec gascity bash). Sling from the rig so the beads" \
    "land in the rig's namespace. Note the workflow root ID it prints."
run_capture "cd '$RIG' && gc sling greetbot/worker greetbot --formula --nudge"
ROOT="$(printf '%s\n' "$RUN_OUTPUT" | sed -n 's/^Started workflow \([A-Za-z0-9-]*\).*/\1/p' | head -1)"
if [ -n "$ROOT" ]; then
  say "Captured workflow root: $ROOT"
else
  ask_value "Workflow root bead ID from the sling output above:" ROOT
fi
pause

heading "Step 7 — Watch the fan-out"
say "scaffold runs first; the instant it closes, THREE steps become ready at" \
    "once and the pool scales to meet them. Cycle these views — and the" \
    "dashboard at http://localhost:8372/ — until the root closes. Watches" \
    "stream forever; Ctrl-C returns to the tutorial:"
watch "gc bd show $ROOT --watch"
run "gc session list"
run "cd '$RIG' && gc bd list | head -30"
run "gc session peek greetbot/worker || true"
say "To look over an agent's shoulder in full: gc session attach" \
    "greetbot/worker (detach with Ctrl-b then d — never Ctrl-c)."
pause

heading "Step 8 — Inspect the result"
run "cd '$RIG' && git log --oneline"
run "cd '$RIG' && python3 -m unittest discover -s tests -v"
run "cd '$RIG' && python3 -m greetbot --lang French --name Ada"
pause

heading "Step 9 — Shut down (or don't)"
say "Stop the city, even 'docker compose down' — the beads and their history" \
    "survive in the store. Sessions are disposable; the work isn't. Bring it" \
    "back any time with: gc start ~/cities/tutorial"
run "gc stop '$CITY' || true"
say "Done. Next: tutorial 2 imports an entire methodology — the superpowers" \
    "pack — into this city: /opt/gascity-tutorials/02-superpowers-factory.sh"
