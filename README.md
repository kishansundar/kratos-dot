# Kratos: NixOS and desktop config

Kratos is the desk PC (i7-8700K, GTX 1070) on NixOS with the mango compositor and the Swiss Quickshell desktop. This repo holds `~/nixos` (the system config; `/etc/nixos` is a link to it) and the desktop configs. It is a bare repo in `~/.dotfiles` whose working folder is the home folder, so every file stays where it is.

## Everyday use

| Command | What it does |
|---|---|
| `dot status` | what changed since the last save |
| `dot diff` | the changed lines |
| `dot add -u` | stage every change to files already in the repo |
| `dot add PATH` | start tracking a new file (a new folder first needs a `!` line in `~/.gitignore`) |
| `dot commit -m "what changed"` | save the staged changes |
| `dot push` | send the saves to GitHub |
| `dot log --oneline` | the list of saves |
| `dotg` | the same repo in lazygit |

`dot` and `dotg` are fish abbreviations for git and lazygit with `--git-dir=$HOME/.dotfiles --work-tree=$HOME`. `~/.gitignore` ignores everything except the folders it lists, so staging everything can never pick up private files.

## What is not in here

RustDesk (its ID and password), 1Password, the Zen and Helium profiles, Obsidian, Spotify, `~/.ssh`, `~/.claude`, Doom Emacs's own source (`~/.config/emacs`), Scrypted's camera setup (`/var/lib/scrypted`), caches and data folders.

## Fresh install

1. Install NixOS with the user `kishan`, then save the installer's hardware file: `cp /etc/nixos/hardware-configuration.nix /tmp/`
2. Put this repo into the home folder:
   ```
   git clone --bare https://github.com/kishansundar/kratos-dot.git ~/.dotfiles
   git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout -f main
   git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no
   ```
3. Put the hardware file back: `cp /tmp/hardware-configuration.nix ~/nixos/`
4. Point the system at `~/nixos` and build: `sudo mv /etc/nixos /etc/nixos.install && sudo ln -s ~/nixos /etc/nixos && sudo nixos-rebuild boot`, then reboot.

## Pushing from Kratos

Pushes use a deploy key that can only write to this repo. On a new install, make one and add `~/.ssh/kratos-dot.pub` on GitHub (repo Settings, Deploy keys, Allow write access):
```
ssh-keygen -t ed25519 -f ~/.ssh/kratos-dot -N "" -C kratos-dot-deploy
git --git-dir=$HOME/.dotfiles config core.sshCommand "ssh -i ~/.ssh/kratos-dot -o IdentitiesOnly=yes"
git --git-dir=$HOME/.dotfiles remote set-url origin git@github.com:kishansundar/kratos-dot.git
```
