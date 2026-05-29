# mac.brew

Personal Mac baseline — Homebrew formulae, casks, App Store apps, and AI CLIs
for a fresh laptop. Excludes work-managed software (Office, Teams, OneDrive,
security agents, MSP/RMM clients).

## Bootstrap a new machine

```sh
# 1. Sign into the Mac App Store first (mas can't sign you in)

# 2. Clone & run
gh auth login
gh repo clone mejohnc-ft/mac.brew ~/mac-setup
bash ~/mac-setup/bootstrap.sh
```

`bootstrap.sh` will:
1. Install Homebrew (if missing)
2. Run `brew bundle` against the `Brewfile` (formulae + casks + App Store via `mas`)
3. Install vendor AI CLIs (Claude Code, Factory `droid`, Cursor, `uv`) and
   symlink OpenAI's Codex CLI from `Codex.app` if present

## Files

| File | Purpose |
|---|---|
| `Brewfile` | Formulae, casks, and `mas` App Store entries |
| `bootstrap.sh` | One-shot installer including vendor AI CLIs |

## Maintenance

```sh
brew update && brew upgrade                          # formulae + casks
brew bundle check   --file=~/mac-setup/Brewfile      # what's missing/outdated
brew bundle cleanup --file=~/mac-setup/Brewfile      # installed but not listed
```

Most GUI apps self-update via Sparkle or built-in updaters (Chrome, VS Code,
Obsidian, Discord, 1Password, Docker, Tailscale, Rogue Amoeba). App Store
apps update via the App Store app itself. AI CLIs each have their own
update commands (e.g. `claude update`, `droid update`).

## Caveats

- **App Store sign-in is manual.** `mas` only installs apps your Apple ID
  already owns; it cannot purchase or sign in.
- **AI CLI install URLs can change.** If a `curl | sh` line in `bootstrap.sh`
  starts failing, check the vendor's current install command.
- **OpenAI Codex CLI** isn't a brew package — it ships inside `Codex.app`.
  Install Codex.app separately, then `bootstrap.sh` symlinks the CLI onto PATH.
