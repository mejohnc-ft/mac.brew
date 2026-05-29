#!/bin/bash
# PostToolUse hook: record provenance with hash + hunks, auto-open plans, presence
# Fires after Write/Edit/MultiEdit. Reads pre-snapshot from PreToolUse hook.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only markdown files
case "$FILE_PATH" in *.md|*.markdown) ;; *) exit 0 ;; esac

# Provenance queue
QUEUE="$HOME/.proof/provenance-queue.jsonl"
LOCK="$HOME/.proof/provenance-queue.lock"
SNAP_DIR="$HOME/.proof/provenance-pre"
mkdir -p "$(dirname "$QUEUE")"
touch "$LOCK"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENTRY_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-12)

# Find and consume pre-snapshot for this file
PRE_HASH="none"
SNAP_ID=$(echo -n "$FILE_PATH" | shasum -a 256 | cut -c1-12)
SNAP_FILE="$SNAP_DIR/$SNAP_ID"
if [ -f "$SNAP_FILE" ]; then
  PRE_HASH=$(cut -f2 "$SNAP_FILE")
  rm -f "$SNAP_FILE"
fi

# Clean up stale snapshots (older than 5 minutes)
find "$SNAP_DIR" -type f -mmin +5 -delete 2>/dev/null

# Compute post-hash from file on disk
if [ -f "$FILE_PATH" ]; then
  POST_HASH=$(shasum -a 256 "$FILE_PATH" | cut -d' ' -f1)
else
  POST_HASH="none"
fi

# Build queue entry based on tool type
# Use flock to coordinate with Swift-side drain (which also uses flock on same lock file).
if [ "$TOOL_NAME" = "Write" ]; then
  (
    flock 200
    jq -nc \
      --arg id "$ENTRY_ID" \
      --arg file "$FILE_PATH" \
      --arg at "$NOW" \
      --arg pre_hash "$PRE_HASH" \
      --arg post_hash "$POST_HASH" \
      '{id: $id, file: $file, by: "ai:claude", tool: "Write",
        at: $at, pre_hash: $pre_hash, post_hash: $post_hash, kind: "full"}' \
      >> "$QUEUE"
  ) 200>"$LOCK"

elif [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "MultiEdit" ]; then
  # Partial edit — compute line-level hunks by diffing pre vs post
  HUNKS="[]"

  if [ "$PRE_HASH" != "none" ] && [ -f "$FILE_PATH" ]; then
    # Use pre-image content from snapshot if available, else fall back to git HEAD
    PRE_CONTENT=""
    PRE_CONTENT_FILE="$SNAP_DIR/${SNAP_ID}.content"
    if [ -f "$PRE_CONTENT_FILE" ]; then
      PRE_CONTENT=$(cat "$PRE_CONTENT_FILE")
      rm -f "$PRE_CONTENT_FILE"
    else
      # Fallback: try to get pre-image content from git
      GIT_REL_PATH=$(git ls-files --full-name "$FILE_PATH" 2>/dev/null)
      if [ -n "$GIT_REL_PATH" ]; then
        PRE_CONTENT=$(git show "HEAD:$GIT_REL_PATH" 2>/dev/null || echo "")
      fi
    fi

    if [ -n "$PRE_CONTENT" ]; then
      HUNKS=$(python3 -c "
import sys, json, difflib

pre_lines = sys.stdin.read().split('\n')
with open(sys.argv[1], 'r') as f:
    post_lines = f.read().split('\n')

matcher = difflib.SequenceMatcher(None, pre_lines, post_lines)
hunks = []
for tag, i1, i2, j1, j2 in matcher.get_opcodes():
    if tag in ('replace', 'insert'):
        hunks.append({
            'start_line': j1 + 1,
            'end_line': j2,
            'lines': post_lines[j1:j2]
        })
print(json.dumps(hunks))
" "$FILE_PATH" <<< "$PRE_CONTENT" 2>/dev/null || echo "[]")
    fi
  fi

  (
    flock 200
    jq -nc \
      --arg id "$ENTRY_ID" \
      --arg file "$FILE_PATH" \
      --arg tool "$TOOL_NAME" \
      --arg at "$NOW" \
      --arg pre_hash "$PRE_HASH" \
      --arg post_hash "$POST_HASH" \
      --argjson hunks "$HUNKS" \
      '{id: $id, file: $file, by: "ai:claude", tool: $tool,
        at: $at, pre_hash: $pre_hash, post_hash: $post_hash,
        kind: "partial", hunks: $hunks}' \
      >> "$QUEUE"
  ) 200>"$LOCK"
fi

# Auto-open markdown files in Proof (dev build) and signal Claude to start collaboration
# Use the dev build from the project's build directory, NOT the installed app
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROOF_DEV_BUILD="$SCRIPT_DIR/build/Build/Products/Debug/Proof.app"
if [ ! -d "$PROOF_DEV_BUILD" ]; then
  # Fallback: check common worktree build locations
  for CANDIDATE in "$SCRIPT_DIR"/.worktrees/*/build/Build/Products/Debug/Proof.app; do
    if [ -d "$CANDIDATE" ]; then
      PROOF_DEV_BUILD="$CANDIDATE"
      break
    fi
  done
fi

if curl -s --max-time 1 http://localhost:9847/windows >/dev/null 2>&1; then
  # Check if file is already open in Proof
  ALREADY_OPEN=$(curl -s --max-time 1 http://localhost:9847/windows 2>/dev/null | \
    jq -e --arg path "$FILE_PATH" '.windows[]? | select(.documentId == $path)' 2>/dev/null)

  if [ -z "$ALREADY_OPEN" ]; then
    # Open in dev build Proof (fall back to installed if no dev build)
    if [ -d "$PROOF_DEV_BUILD" ]; then
      open "$PROOF_DEV_BUILD" --args "$FILE_PATH" 2>/dev/null
    else
      open -a Proof "$FILE_PATH" 2>/dev/null
    fi

    # Signal Claude to start the event poller for back-and-forth collaboration
    echo "PROOF_OPENED: $FILE_PATH"
    echo "ACTION_REQUIRED: Start a background event poller for this file so you can respond to user comments and feedback in Proof. Follow the 'Background Event Monitoring' section of the proof-agent-ops skill."
  fi
else
  # Proof isn't running yet — launch dev build with the file
  if [ -d "$PROOF_DEV_BUILD" ]; then
    open "$PROOF_DEV_BUILD" --args "$FILE_PATH" 2>/dev/null
    echo "PROOF_OPENED: $FILE_PATH"
    echo "ACTION_REQUIRED: Start a background event poller for this file so you can respond to user comments and feedback in Proof. Follow the 'Background Event Monitoring' section of the proof-agent-ops skill."
  fi
fi

# If Proof is running, refresh presence
if curl -s --max-time 1 http://localhost:9847/windows >/dev/null 2>&1; then
  curl -s -X POST http://localhost:9847/presence \
    -H 'Content-Type: application/json' -H 'X-Agent-Id: claude' \
    -d '{"status":"acting","summary":"Editing..."}' >/dev/null 2>&1
fi

exit 0
