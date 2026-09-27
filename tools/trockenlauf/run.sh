#!/usr/bin/env bash
# Trockenlauf eines Entwurfs ohne Studio: Syntax (luau-compile) und Ausfuehrung mit Ersatz-API.
# Aufruf: tools/trockenlauf/run.sh drafts/<datei>.lua ['Vector3.new(1,0,0)' | 30]
# Liegt neben dem Entwurf eine <datei>.test.luau, laeuft sie danach; sie sieht den Rueckgabewert
# des Entwurfs (z. B. ein Modul) als ENTWURF.
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
TEST="${DRAFT%.lua}.test.luau"
"$BIN/luau-compile" --text "$DRAFT" >/dev/null && echo "Syntax OK: $DRAFT"
RUN="$(mktemp --suffix=.luau)"
trap 'rm -f "$RUN"' EXIT
sed "s/WIND_IN/$WIND/" "$DIR/stubs.luau" > "$RUN"
{
	echo "ENTWURF = (function()"
	cat "$DRAFT"
	echo
	echo "end)()"
	cat "$DIR/report.luau"
	if [ -f "$TEST" ]; then
		echo "do"
		cat "$TEST"
		echo
		echo "end"
	fi
} >> "$RUN"
echo "WIND = $WIND"
[ -f "$TEST" ] && echo "Test: $TEST"
"$BIN/luau" "$RUN"
