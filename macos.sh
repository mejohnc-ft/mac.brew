#!/usr/bin/env bash
# macos.sh — apply personal macOS UI/UX defaults.
# Mirrors the live settings captured from jchristensen's machine.
# Skips power/sleep (managed manually).
# Safe to re-run; idempotent.

set -euo pipefail

echo "▶ Applying macOS defaults..."

# ─── Dock ─────────────────────────────────────────────────────────
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock tilesize -int 35
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true

# Hot corners
#   1 = disabled         5 = Start Screen Saver   11 = Launchpad
#   2 = Mission Control  6 = Disable Screen Saver 12 = Notification Center
#   3 = Application Wins 10 = Put Display to Sleep 13 = Lock Screen
#   4 = Desktop                                    14 = Quick Note
defaults write com.apple.dock wvous-bl-corner -int 5   # bottom-left  → Screen Saver
defaults write com.apple.dock wvous-br-corner -int 4   # bottom-right → Desktop
defaults write com.apple.dock wvous-tr-corner -int 14  # top-right    → Quick Note

# ─── Finder ───────────────────────────────────────────────────────
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"  # column view
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder ShowPathbar -bool true

# ─── Global appearance & input ────────────────────────────────────
defaults write -g AppleInterfaceStyle -string "Dark"
defaults write -g NSAutomaticCapitalizationEnabled -bool true
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool true

# ─── Menu bar clock ───────────────────────────────────────────────
defaults write com.apple.menuextra.clock ShowAMPM -bool true
defaults write com.apple.menuextra.clock ShowDate -int 0
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock TimeAnnouncementsEnabled -bool false

# ─── Trackpad ─────────────────────────────────────────────────────
# Built-in trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
# External (Magic Trackpad) — mirror so behavior is consistent
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
# Tap-to-click also needs these globals
defaults write -g com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# ─── Screenshots ──────────────────────────────────────────────────
defaults write com.apple.screencapture style -string "selection"
defaults write com.apple.screencapture video -bool true

# ─── Restart affected apps so changes take effect ────────────────
for app in Dock Finder SystemUIServer; do
  killall "$app" >/dev/null 2>&1 || true
done

echo "✅ macOS defaults applied."
echo ""
echo "Manual follow-ups (can't be scripted):"
echo "  • Sign into Apple ID / iCloud"
echo "  • Grant Accessibility / Screen Recording / Full Disk Access"
echo "    to apps that need it (BetterTouchTool, superwhisper, etc.)"
echo "  • Touch ID enrollment"
echo "  • Wi-Fi passwords / Bluetooth pairings"
