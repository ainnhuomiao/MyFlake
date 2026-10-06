#!/usr/bin/env bash

set -euo pipefail

# Single-machine setup: rebuild the local host directly, no interactive picker.
# Usage: rebuild.sh [host]   (default: $NH_HOST, else "nixos")
host="${1:-${NH_HOST:-nixos}}"

# nh self-elevates with sudo when needed; nom output is built in
echo "🚀 Rebuilding $host..."
nh os switch . -H "$host"
