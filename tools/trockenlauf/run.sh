#!/usr/bin/env bash
# Trockenlauf eines Entwurfs ohne Studio: Syntax (luau-compile) und Ausfuehrung mit Ersatz-API.
# Aufruf: tools/trockenlauf/run.sh drafts/S141_kind-mit-ballon.lua ['Vector3.new(1,0,0)' | 30]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="${LUAU_BIN:-$DIR/.bin}"
if [ ! -x "$BIN/luau" ]; then
	mkdir -p "$BIN"
	curl -sSL -o "$BIN/luau.zip" https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
	unzip -o -q "$BIN/luau.zip" -d "$BIN" && rm "$BIN/luau.zip"
fi
DRAFT="$1"
WIND="${2:-Vector3.new(1,0,0)}"
"$BIN/luau-compile" --text "$DRAFT" >/dev/null && echo "Syntax OK: $DRAFT"
RUN="$(mktemp --suffix=.luau)"
sed "s/WIND_IN/$WIND/" "$DIR/stubs.luau" > "$RUN"
cat "$DRAFT" "$DIR/report.luau" >> "$RUN"
echo "WIND = $WIND"
"$BIN/luau" "$RUN"
rm -f "$RUN"
