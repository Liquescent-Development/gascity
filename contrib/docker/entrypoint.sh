#!/usr/bin/env bash
# Container entrypoint: seed machine-wide supervisor config, then exec CMD.
set -euo pipefail

mkdir -p "$HOME/.gc"

# Bind the supervisor (API + dashboard, port 8372) to all interfaces so the
# host reaches it through Docker's port mapping. allow_mutations keeps writes
# enabled on the non-loopback bind (the field exists for exactly this
# containerized case). Written once; delete the file to regenerate.
if [ ! -f "$HOME/.gc/supervisor.toml" ]; then
  cat > "$HOME/.gc/supervisor.toml" <<'EOF'
[supervisor]
port = 8372
bind = "0.0.0.0"
allow_mutations = true
EOF
fi

exec "$@"
