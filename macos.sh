#!/usr/bin/env bash
# macos.sh — apply personal macOS UI/UX defaults.
# Mirrors the live settings captured from jchristensen's machine,
# plus dev-friendly tweaks. Skips power/sleep. Sudo-free.
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
#   1=disabled  2=Mission Control  3=App Windows  4=Desktop
#   5=Screen Saver  6=Disable Screen Saver  10=Display Sleep
#   11=Launchpad  12=Notification Center  13=Lock Screen  14=Quick Note
defaults write com.apple.dock wvous-bl-corner -int 5   # bottom-left  → Screen Saver
defaults write com.apple.dock wvous-br-corner -int 4   # bottom-right → Desktop
defaults write com.apple.dock wvous-tr-corner -int 14  # top-right    → Quick Note

# ─── Finder ───────────────────────────────────────────────────────
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"   # column view
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder ShowPathbar -bool true
# (B) Finder extras
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search current folder
chflags nohidden "$HOME/Library" 2>/dev/null || true

# ─── Global appearance & input ────────────────────────────────────
defaults write -g AppleInterfaceStyle -string "Dark"
defaults write -g NSAutomaticCapitalizationEnabled -bool true
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool true
# (B) show all extensions everywhere
defaults write -g AppleShowAllExtensions -bool true

# ─── (A) Keyboard / text — dev-friendly ───────────────────────────
defaults write -g KeyRepeat -int 2              # fast repeat
defaults write -g InitialKeyRepeat -int 15      # short delay before repeat
defaults write -g ApplePressAndHoldEnabled -bool false   # keys repeat in editors
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false

# ─── Menu bar clock ───────────────────────────────────────────────
defaults write com.apple.menuextra.clock ShowAMPM -bool true
defaults write com.apple.menuextra.clock ShowDate -int 0
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock TimeAnnouncementsEnabled -bool false

# ─── Trackpad ─────────────────────────────────────────────────────
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write -g com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# ─── (C) Screenshots ──────────────────────────────────────────────
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture style -string "selection"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture show-thumbnail -bool false
defaults write com.apple.screencapture video -bool true

# ─── (D) Safari ───────────────────────────────────────────────────
# NOTE: Modern macOS sandboxes Safari preferences. If these no-op,
# the terminal needs Full Disk Access (System Settings → Privacy & Security).
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null || true
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true 2>/dev/null || true
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false 2>/dev/null || true
defaults write com.apple.Safari WebKitDeveloperExtras -bool true 2>/dev/null || true
defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true 2>/dev/null || true

# ─── (E) Snappier animations ──────────────────────────────────────
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock launchanim -bool false

# ─── (F) Save / print dialogs expanded by default ─────────────────
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true

# ─── (G) TextEdit plain text, UTF-8 ───────────────────────────────
defaults write com.apple.TextEdit RichText -int 0
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# ─── (H) Disable UI sound effects ─────────────────────────────────
defaults write -g com.apple.sound.beep.feedback -int 0   # no beep on volume change
defaults write -g com.apple.sound.uiaudio.enabled -int 0 # disable UI sound effects

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
echo "  • Touch ID enrollment, Wi-Fi passwords, Bluetooth pairings"
echo "  • If Safari prefs didn't apply, grant Full Disk Access to Terminal"
echo "    and re-run macos.sh, or toggle them in Safari → Settings"
