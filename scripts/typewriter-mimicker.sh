#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: typewriter-mimicker INPUT OUTPUT.pdf [--dpi N] [--preset NAME] [--font FONT.ttf]" >&2
  exit 2
fi

input=$1
output=$2
shift 2

repo_root=${TYPEWRITER_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

if [ -w "$repo_root" ]; then
  source_root=$repo_root
else
  cache_base=${XDG_CACHE_HOME:-$HOME/.cache}/typewriter-mimicker
  repo_key=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
  source_root="$cache_base/source-$repo_key"
  ready_file="$source_root/.typewriter-cache-ready"

  if [ ! -f "$ready_file" ]; then
    mkdir -p "$cache_base"
    rm -rf "$source_root"
    cp -R "$repo_root" "$source_root"
    chmod -R u+w "$source_root"
    touch "$ready_file"
  fi
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

stack --stack-yaml "$source_root/formatter/stack.yaml" run -- "$input" > "$workdir/pages.json"
uv --project "$source_root/renderer" run python "$source_root/renderer/main.py" \
  "$workdir/pages.json" \
  --output "$output" \
  "$@"
