#!/usr/bin/env bash
# Interactive runner for Tutorial 2 — The superpowers factory.
# Self-paced version: /opt/gascity-tutorials/02-superpowers-factory.md
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CITY="$HOME/cities/tutorial"
RIG="$HOME/projects/greetbot"

heading "Tutorial 2 — The superpowers factory"
say "You know superpowers from Claude Code: brainstorm first, write plans," \
    "strict TDD, request review. There the discipline is persuasion — skill" \
    "files the model chooses to follow. The superpowers PACK turns each" \
    "skill into graph structure the orchestrator enforces: approval gates" \
    "that loop instead of falling through, TDD steps that are dependency-" \
    "gated beads, review fan-outs that iterate to a verdict."
say "Prerequisite: Tutorial 1's city and greetbot rig."
pause

if [ ! -d "$CITY" ]; then
  echo "City $CITY not found — run 01-your-first-fleet.sh first." >&2
  exit 1
fi
run "gc start '$CITY' || true"

heading "Step 1 — Import the pack"
say "A pack is a directory with a pack.toml: agents, formulas, orders. Your" \
    "city IS a pack (the local root pack); importing a shared pack makes its" \
    "contents read like your own, namespaced by the import binding."
run "cd '$CITY' && gc import add https://github.com/gastownhall/gascity-packs/tree/main/superpowers"
run "cd '$CITY' && grep -A2 'imports.superpowers' pack.toml"
say "The pack itself imports the base gascity pack (build-base contract +" \
    "gc.* operator agents) transitively. Packs compose."
pause

heading "Step 2 — Give the rig its worker roles"
say "The build formula routes steps to rig-scoped roles (gc.run-operator," \
    "gc.task-decomposer, the superpowers agents). Each working rig needs the" \
    "roles sub-pack wired in city.toml. This step edits your [[rigs]] entry;" \
    "if you've customized city.toml, review before writing."
say "Adding under the greetbot [[rigs]] entry:" \
    '  [rigs.imports.gc]' \
    '  source = "https://github.com/gastownhall/gascity-packs.git//gascity/roles"'
if grep -q 'rigs.imports.gc' "$CITY/city.toml" 2>/dev/null; then
  say "city.toml already has a rigs.imports.gc entry — leaving it alone."
else
  run "python3 - '$CITY/city.toml' <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
block = '\n[rigs.imports.gc]\nsource = \"https://github.com/gastownhall/gascity-packs.git//gascity/roles\"\n'
m = re.search(r'(\[\[rigs\]\]\s*\nname = \"greetbot\"\n)', text)
if not m:
    sys.exit('could not find the greetbot [[rigs]] entry in ' + path)
text = text[:m.end(1)] + block + text[m.end(1):]
open(path, 'w').write(text)
print('added rigs.imports.gc to', path)
PYEOF"
fi
run "cd '$CITY' && gc import install"
run "cd '$CITY' && gc import check"
run "cd '$CITY' && gc config show --validate"
run "cd '$CITY' && gc formula list"
say "See the superpowers-* family? Inspect the whole factory:"
run "cd '$CITY' && gc formula show superpowers-build"
say "prepare → requirements (two approval gates) → plan → plan-review →" \
    "decompose → implement (convoy drain) → review fan-out → finalize →" \
    "publish. All of it arrived as configuration — none of it is hardcoded" \
    "in Gas City."
pause

heading "Step 3 — Run the factory"
say "Give it a real feature. Create the work bead from the rig directory so" \
    "it lands in the rig's namespace; note the printed bead ID."
run_capture "cd '$RIG' && gc bd create 'Add a --shout flag to greetbot that uppercases the greeting and adds exclamation marks, with tests'"
BEAD="$(printf '%s\n' "$RUN_OUTPUT" | sed -n 's/.*Created issue: \([A-Za-z0-9-]*\).*/\1/p' | head -1)"
if [ -n "$BEAD" ]; then
  say "Captured bead ID: $BEAD"
else
  ask_value "Bead ID from the output above:" BEAD
fi
say "artifact_root (the only required variable) is where the factory writes" \
    "its design, spec, plan, and reports inside the rig. Defaults: no human" \
    "gates, nothing pushed (push=false, open_pr=false)."
run "cd '$RIG' && gc sling gc.run-operator $BEAD --on superpowers-build --var artifact_root=plans/shout-flag/build"
say "If gc.run-operator didn't resolve, retry with the rig-qualified name:" \
    "  gc sling greetbot/gc.run-operator $BEAD --on superpowers-build ..."
pause

heading "Step 4 — Watch a methodology execute"
say "Same tools as Tutorial 1, bigger show. Second terminal for the stream:" \
    "gc events --follow. Phases to spot: brainstorming writes design + spec" \
    "into the artifact root (gates loop on failure) → plan + plan-review →" \
    "decompose into a convoy → implementers drain tasks with forced TDD" \
    "order → double review fan-out loops to a 'done' verdict → finisher." \
    "Watches stream forever; Ctrl-C returns to the tutorial."
watch "gc bd show $BEAD --watch"
run "gc session list"
run "ls -R '$RIG/plans/shout-flag/build' 2>/dev/null || echo 'artifacts not written yet — check again in a bit'"
run "cd '$RIG' && gc bd list | head -30"
run "cd '$RIG' && git branch -a"
say "Cycle these (and the dashboard at http://localhost:8372/) until the" \
    "workflow closes. This can take a while — a whole methodology is running."
pause

heading "Step 5 — Inspect the factory's output"
run "ls -R '$RIG/plans/shout-flag/build'"
run "cd '$RIG' && git log --oneline --all | head -20"
say "The feature is on a local branch with tests — the factory didn't push" \
    "because you didn't pass --var push=true. Review and merge it yourself," \
    "or re-run fully autonomous next time:" \
    "  gc sling gc.run-operator <bead> --on superpowers-build \\" \
    "    --var artifact_root=... --var interaction_mode=autonomous \\" \
    "    --var push=true --var open_pr=true"
say "More knobs (see the .md for the full table): drain_policy=same-session" \
    "for small changes, brainstorming_approval_mode=interactive to make the" \
    "design/spec gates wait for YOU, review_mode, max_iterations."
pause

heading "Done"
say "You consumed a pack: nine agents, twelve formulas, the skills you" \
    "already trusted — one import, one sling. Swap superpowers-build for" \
    "bmad-build or compound-build (same variables) and the same engine" \
    "becomes a different factory. That's zero-hardcoded-roles doing its job."
