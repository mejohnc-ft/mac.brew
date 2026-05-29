# mac.brew

Personal Mac baseline — Homebrew formulae and casks for a fresh laptop.
Excludes work-managed software (Office, Teams, OneDrive, security agents, MSP/RMM clients).

## Bootstrap a new machine

```sh
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone this repo
gh auth login
gh repo clone mejohnc-ft/mac.brew ~/mac-setup

# 3. Install everything
brew bundle --file=~/mac-setup/Brewfile
```

## Maintenance

```sh
brew update && brew upgrade        # update formulae + casks
brew bundle check --file=Brewfile  # what's missing or outdated
brew bundle cleanup --file=Brewfile  # show installed-but-not-in-Brewfile
```

Most GUI apps self-update via Sparkle / built-in updaters (Chrome, VS Code,
Obsidian, Discord, 1Password, Docker, Tailscale, Rogue Amoeba apps).
Brew is mainly responsible for the initial install.
