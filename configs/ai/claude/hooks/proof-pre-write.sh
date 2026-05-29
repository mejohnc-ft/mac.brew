#!/bin/bash
# PreToolUse hook: snapshot pre-edit file hash + send presence to Proof
# Fires before Write/Edit/MultiEdit so PostToolUse can compute diffs.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only markdown files
case "$FILE_PATH" in *.md|*.markdown) ;; *) exit 0 ;; esac

# Send presence to Proof so user sees "Claude Code is editing..."
if curl -s --max-time 1 http://localhost:9847/windows >/dev/null 2>&1; then
  curl -s -X POST http://localhost:9847/presence \
    -H 'Content-Type: application/json' -H 'X-Agent-Id: claude' \
    -d '{"status":"acting","summary":"Editing..."}' >/dev/null 2>&1
fi

# Generate snapshot and compute pre-hash
SNAP_DIR="$HOME/.proof/provenance-pre"
mkdir -p "$SNAP_DIR"

if [ -f "$FILE_PATH" ]; then
  PRE_HASH=$(shasum -a 256 "$FILE_PATH" | cut -d' ' -f1)
else
  PRE_HASH="none"
fi

# Store pre-hash keyed by file path (one snapshot per file)
# PostToolUse finds the latest snapshot for this file path.
SNAP_ID=$(echo -n "$FILE_PATH" | shasum -a 256 | cut -c1-12)
printf '%s\t%s\n' "$FILE_PATH" "$PRE_HASH" > "$SNAP_DIR/$SNAP_ID"

# Also store file content for accurate hunk computation (git HEAD may differ
# from working tree if there are uncommitted edits)
if [ -f "$FILE_PATH" ] && [ "$PRE_HASH" != "none" ]; then
  cp "$FILE_PATH" "$SNAP_DIR/${SNAP_ID}.content"
fi

exit 0
