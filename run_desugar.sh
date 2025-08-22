#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_desugar.sh path/to/file.daml
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/file.daml"
  exit 1
fi

DAMLF="$1"
if [[ ! -f "$DAMLF" ]]; then
  echo "Error: '$DAMLF' not found."
  exit 1
fi

BIN="$HOME/daml/sdk/bazel-bin/compiler/damlc/damlc"
if [[ ! -x "$BIN" ]]; then
  echo "Error: damlc not found or not executable at:"
  echo "  $BIN"
  echo "Build //compiler/damlc once before using this script."
  exit 1
fi

echo "▶ Running desugar on: $DAMLF"
"$BIN" desugar "$DAMLF"

DIR="$(dirname "$DAMLF")"
OUT_HS="$DIR/haskell_code.hs"
OUT_AST_TXT="$DIR/haskell_ast.txt"
OUT_AST_JSON="$DIR/haskell_ast.json"

# If you prefer JSON, wrap the text dump as a JSON string (optional):
if [[ -f "$OUT_AST_TXT" ]]; then
  printf '%s' "$(jq -Rs . < "$OUT_AST_TXT")" > "$OUT_AST_JSON" 2>/dev/null || true
fi

# Report results
[[ -f "$OUT_HS"      ]] || { echo "⚠️  Missing $OUT_HS"; exit 1; }
[[ -f "$OUT_AST_TXT" ]] || { echo "⚠️  Missing $OUT_AST_TXT"; exit 1; }

echo "✅ Wrote:"
echo "   - $OUT_HS"
echo "   - $OUT_AST_TXT"
[[ -f "$OUT_AST_JSON" ]] && echo "   - $OUT_AST_JSON (wrapped as JSON string)"
