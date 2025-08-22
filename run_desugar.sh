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
  echo "Make sure you've built //compiler/damlc already."
  exit 1
fi

echo "▶ Running: $BIN desugar \"$DAMLF\""
"$BIN" desugar "$DAMLF"

OUT_FILE="$(dirname "$DAMLF")/haskell_ast.txt"
if [[ -f "$OUT_FILE" ]]; then
  echo "✅ Wrote AST to: $OUT_FILE"
else
  echo "⚠️ Expected output not found at: $OUT_FILE"
  exit 1
fi
