# Gas City tutorial image: the gc orchestrator, its required runtime tools
# (bd, dolt, tmux, jq, git, flock), and Claude Code as the backing agent —
# everything needed to run a city in one container.
#
# Build from the repository root (the build context must be the repo root so
# the Go source and the pinned install scripts are available):
#
#   docker build -f contrib/docker/Dockerfile -t gascity-tutorial .
#
# Or use contrib/docker/docker-compose.yml, which sets the context for you.
#
# Version pins follow deps.env (dolt, bd) and contrib/k8s/Dockerfile.base
# (Claude Code). Override with --build-arg to bump.

# --- Build stage: compile gc ------------------------------------------------
# The dashboard SPA is committed under internal/api/dashboardspa/dist and
# embedded via go:embed, so no Node build is needed. The build is pure Go
# (modernc.org/sqlite; dolt is an external process), so CGO stays off.
FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/gc ./cmd/gc

# --- Runtime stage ------------------------------------------------------------
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# deps.env: DOLT_VERSION / BD_VERSION. Claude Code pin matches contrib/k8s.
ARG DOLT_VERSION=2.1.7
ARG BD_VERSION=v1.0.4
ARG CLAUDE_CODE_VERSION=2.1.123

# Required runtime tools per docs/getting-started/installation.md plus lsof
# (a hard `gc init` dependency check): tmux (default session provider), jq,
# git, flock (util-linux), and curl/ca-certificates for the pinned
# installers; procps/python3/sudo match the agent environment of
# contrib/k8s/Dockerfile.base.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git jq lsof procps python3 sudo tmux util-linux \
    && rm -rf /var/lib/apt/lists/*

# SHA-pinned installers shared with CI and the k8s images.
COPY .github/scripts/install-dolt-archive.sh \
     .github/scripts/install-bd-archive.sh \
     .github/scripts/install-claude-native.sh \
     /tmp/scripts/
RUN /tmp/scripts/install-dolt-archive.sh "${DOLT_VERSION}" \
    && /tmp/scripts/install-bd-archive.sh "${BD_VERSION}" \
    && /tmp/scripts/install-claude-native.sh "${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/scripts

COPY --from=build /out/gc /usr/local/bin/gc

# Non-root user: Claude Code's --dangerously-skip-permissions (the default
# "unrestricted" permission mode gc launches agents with) refuses to run as
# root, so the container must not run as root.
RUN useradd -m -s /bin/bash gcagent \
    && echo "gcagent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gcagent \
    && chmod 0440 /etc/sudoers.d/gcagent

# Tutorials live outside $HOME so the home volume never shadows them.
COPY --chown=gcagent:gcagent contrib/docker/tutorials/ /opt/gascity-tutorials/
COPY contrib/docker/entrypoint.sh /usr/local/bin/gascity-entrypoint
RUN chmod 0755 /usr/local/bin/gascity-entrypoint /opt/gascity-tutorials/*.sh

USER gcagent
ENV HOME=/home/gcagent
# Leave GC_BEADS unset: the default provider resolution is the bd/Dolt
# contract, which the `gc bd` passthrough (used throughout the tutorials)
# requires. GC_BEADS=dolt would force the native-only store and break it.

# Dolt refuses to commit without an identity (a `gc init` dependency check),
# and agents need a git identity to commit in rigs. Override with your own:
#   dolt config --global --add user.name "..." ; git config --global user.name "..."
RUN dolt config --global --add user.name "Gas City Agent" \
    && dolt config --global --add user.email "gcagent@localhost" \
    && git config --global user.name "Gas City Agent" \
    && git config --global user.email "gcagent@localhost" \
    && git config --global init.defaultBranch main

WORKDIR /home/gcagent

# Supervisor API + dashboard (the entrypoint binds it to 0.0.0.0).
EXPOSE 8372

ENTRYPOINT ["gascity-entrypoint"]
# Keep the container alive; users enter with `docker compose exec gascity bash`.
CMD ["sleep", "infinity"]
