# mac.brew

Personal Mac baseline — Homebrew formulae, casks, App Store apps, AI CLIs,
macOS defaults, Dock layout, and safe dotfiles for a fresh laptop. Excludes
work-managed software (Office, Teams, OneDrive, security agents, MSP/RMM).

## Bootstrap a new machine

```sh
# 1. Sign into the Mac App Store (mas can't sign you in)
# 2. Run:
gh auth login
gh repo clone mejohnc-ft/mac.brew ~/mac-setup
bash ~/mac-setup/bootstrap.sh
```

`bootstrap.sh` runs in six steps:
1. Install Homebrew
2. `brew bundle` — formulae, casks, App Store apps (via `mas`)
3. Vendor AI CLIs — Claude Code, Factory `droid`, Cursor, `uv`; symlink
   OpenAI Codex from `Codex.app` onto PATH
4. Symlink dotfiles from `configs/` into `$HOME` (`.zshrc`, `.gitconfig`,
   `.config/zed/settings.json`, `.config/gh/config.yml`)
5. Pin Dock apps with `dockutil`
6. Apply macOS UI/UX defaults

## Files

| File | Purpose |
|---|---|
| `Brewfile` | Formulae, casks, `mas` App Store entries, `dockutil` |
| `bootstrap.sh` | One-shot installer |
| `macos.sh` | macOS UI/UX defaults (Dock, Finder, hot corners, trackpad, keyboard, screenshots, Safari, animations, sound) |
| `configs/` | Safe dotfiles only — never contains tokens or secrets |

## Manual sign-ins after bootstrap

These apps sync via cloud accounts (no need to script):

- **Apple ID / iCloud** (System Settings)
- **1Password** — restores all passwords + SSH keys
- **VS Code** — Settings Sync via GitHub login
- **BetterTouchTool** — account sync or restore local preset
- **Tailscale**, **Paste**, **Discord**, **Docker Desktop**
- **Obsidian** — open vault (Obsidian Sync / iCloud / git)
- **Claude Code, droid, cursor-agent, codex** — each CLI re-auths

## Permission grants (System Settings → Privacy & Security)

| Permission | Apps that need it |
|---|---|
| Accessibility | BetterTouchTool, superwhisper, TextSniper |
| Screen Recording | TextSniper, Loopback (if used) |
| Input Monitoring | BetterTouchTool |
| Full Disk Access | Terminal (so Safari prefs in `macos.sh` apply) |

## Maintenance

```sh
brew update && brew upgrade
brew bundle check   --file=~/mac-setup/Brewfile
brew bundle cleanup --file=~/mac-setup/Brewfile
```

Most GUI apps self-update via Sparkle or built-in updaters. App Store apps
update via the App Store. AI CLIs each have their own update commands
(`claude update`, `droid update`).

## Security & exclusions

The following are **never** committed:

- `~/.config/gh/hosts.yml` (GitHub auth token)
- `~/.config/franklin/edge-brain-ingest.env` (.env with secrets)
- `~/.claude/`, `~/.codex/`, `~/.factory/`, `~/.cursor/` (session tokens,
  conversation history)
- SSH private keys (`~/.ssh/id_*`)
- Anything under work-flagged directories (`DefensX`, work-managed configs)

## Caveats

- **App Store sign-in is manual** — `mas` can install only apps your Apple
  ID already owns.
- **AI CLI install URLs can change** — if a `curl | sh` line in
  `bootstrap.sh` fails, check the vendor's current install command.
- **OpenAI Codex CLI** ships inside `Codex.app` — install the desktop app
  separately, then bootstrap symlinks the CLI onto PATH.
- **Safari prefs are sandboxed** on modern macOS — grant Terminal Full
  Disk Access if the Safari section of `macos.sh` doesn't take.
