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
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
cp -R "$repo_root" "$workdir/source"
chmod -R u+w "$workdir/source"

stack --stack-yaml "$workdir/source/formatter/stack.yaml" run -- "$input" > "$workdir/pages.json"
uv --project "$workdir/source/renderer" run python "$workdir/source/renderer/main.py" \
  "$workdir/pages.json" \
  --output "$output" \
  "$@"
