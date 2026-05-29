#!/usr/bin/env bash
# power.sh — apply liberal pmset sleep settings.
# Moderate preset: long-running tasks survive idle periods, battery still
# sleeps eventually to preserve charge.
#
# Requires sudo. bootstrap.sh caches sudo upfront in step 3 so this runs
# unattended without extra prompts.

set -euo pipefail

echo "▶ Applying power management defaults (Moderate preset)…"

# ─── Battery — relax from aggressive defaults ─────────────────────
# Current default on this user's machine: sleep 1, displaysleep 10.
# Moderate: still sleep eventually, but not after 60 seconds.
sudo pmset -b sleep 30
sudo pmset -b displaysleep 15
sudo pmset -b disksleep 0          # SSDs ignore this anyway
sudo pmset -b tcpkeepalive 0       # Save battery; TCP closes during sleep
sudo pmset -b powernap 0
sudo pmset -b lessbright 1         # Auto-dim on battery

# ─── AC — keep liberal AC behavior ────────────────────────────────
sudo pmset -c sleep 0              # Never sleep on AC
sudo pmset -c displaysleep 120     # Keep current 2-hour display idle
sudo pmset -c disksleep 0
sudo pmset -c tcpkeepalive 1       # Keep TCP / SSH alive
sudo pmset -c powernap 1
sudo pmset -c womp 1               # Wake on Magic Packet (Wake on LAN)
sudo pmset -c acwake 0             # Don't wake when AC plug/unplug changes
sudo pmset -c lessbright 0         # Don't auto-dim on AC

# ─── Both — general wake/standby behavior ─────────────────────────
sudo pmset -a lidwake 1            # Wake when lid opens
sudo pmset -a ttyskeepawake 1      # Active SSH / terminal keeps Mac awake
sudo pmset -a autopoweroff 0       # Skip deep-sleep after hours of sleep

echo "✅ Power settings applied."
echo
echo "Current state:"
pmset -g custom 2>&1 \
  | grep -E "^(Battery|AC)|sleep|displaysleep|tcpkeepalive|powernap|womp|lidwake|acwake|ttyskeepawake|autopoweroff|lessbright" \
  | head -40
