#!/usr/bin/env bash
# Re-exports the OpenAPI contract from vmito-be into this repo.
#
#   ./tool/sync_openapi.sh
#
# `openapi/openapi.json` is committed on purpose: it makes DTO codegen
# reproducible, and it turns every backend contract change into a reviewable
# diff in this repo rather than a silent shift under the generated models.
#
# Run this, then `dart run build_runner build`, whenever the backend changes a
# DTO or controller.
set -euo pipefail

BACKEND_DIR="${VMITO_BE_DIR:-$(cd "$(dirname "$0")/../../vmito-be" && pwd)}"
TARGET="$(cd "$(dirname "$0")/.." && pwd)/openapi/openapi.json"

if [[ ! -f "$BACKEND_DIR/package.json" ]]; then
  echo "vmito-be not found at $BACKEND_DIR" >&2
  echo "Set VMITO_BE_DIR to its path and retry." >&2
  exit 1
fi

echo "Exporting from $BACKEND_DIR ..."
# The export script refuses to write a document produced without the
# @nestjs/swagger CLI plugin, so a plugin regression fails here, not later.
(cd "$BACKEND_DIR" && npm run --silent openapi:export)

cp "$BACKEND_DIR/openapi.json" "$TARGET"
echo "Updated $TARGET"
echo
echo "Next: dart run build_runner build"
echo "Review the diff — it is the backend's contract change."
