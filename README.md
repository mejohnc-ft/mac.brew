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

`bootstrap.sh` runs in fourteen steps, styled with [`gum`](https://github.com/charmbracelet/gum):

1. **System check** — macOS version, user, disk available
2. **Homebrew** — install if missing
3. **brew bundle (no App Store)** — formulae + casks only (`Brewfile`)
4. **Apple ID sign-in** — deep-link to System Settings; `gum confirm`. Skippable.
5. **App Store apps** — `brew bundle --file=Brewfile.appstore` only if step 4
   was confirmed and `mas account` sees a session. Otherwise quietly skipped
   (no eleven failed sign-in prompts in a row).
6. **1Password unlock** — open 1Password, prompt for Touch ID + CLI integration.
   Sets the stage for future SSH-key / Tailscale-auth-key fetching.
7. **Vendor AI CLIs install** — Claude Code, Factory `droid`, Cursor, `uv`;
   symlink OpenAI Codex from `Codex.app` onto PATH.
8. **AI CLI auth** — per-tool `gum confirm`; if accepted, launches the tool
   interactively for browser-based sign-in.
9. **Dotfile symlinks** — `.zshrc`, `.gitconfig`, `.config/zed`, `.config/gh`
10. **AI config restore** — `rsync --ignore-existing` from `configs/ai/`
11. **Dock pin** via `dockutil`
12. **macOS UI defaults** — `macos.sh`
13. **Permission grants (interactive)** — per-permission deep-links to System
    Settings → Privacy & Security, with `gum confirm` between each:
    Accessibility, Screen Recording, Input Monitoring, Full Disk Access.
14. **Agent review (optional)** — `gum confirm` → Claude Code verifies brew
    bundle status (both files), AI configs, dotfile symlinks, Dock layout,
    macOS defaults, AI CLI auth, prints a markdown ✓/⚠/✗ report.

## Files

| File | Purpose |
|---|---|
| `Brewfile` | Formulae + casks (no App Store apps) |
| `Brewfile.appstore` | App Store apps — installed conditionally on Apple ID sign-in |
| `bootstrap.sh` | One-shot installer, 14 steps |
| `macos.sh` | macOS UI/UX defaults (Dock, Finder, hot corners, trackpad, keyboard, screenshots, Safari, animations, sound) |
| `configs/` | Safe dotfiles + AI tool configs — never contains tokens or secrets |
| `configs/ai/claude/` | Claude Code settings, hooks, agents, skills, plugin manifest |
| `configs/ai/codex/` | Codex config (sanitized), keybindings, rules, skills |

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
brew bundle check   --file=~/mac-setup/Brewfile.appstore
brew bundle cleanup --file=~/mac-setup/Brewfile
```

Most GUI apps self-update via Sparkle or built-in updaters. App Store apps
update via the App Store. AI CLIs each have their own update commands
(`claude update`, `droid update`).

## Security & exclusions

The following are **never** committed:

- `~/.config/gh/hosts.yml` (GitHub auth token)
- `~/.config/franklin/edge-brain-ingest.env` (.env with secrets)
- `~/.claude/`, `~/.codex/`, `~/.factory/`, `~/.cursor/` **state** (session
  tokens, history, sqlite logs, sessions, telemetry, plugin caches).
  Only the **declarative** parts are committed under `configs/ai/`:
  settings.json, hooks, agents, skills, rules, plugin manifests.
- `~/.codex/config.toml` work `[projects.*]` sections (paths stripped
  before commit; only personal / generic paths preserved)
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
