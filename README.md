# Portable private development environment

This is a **complete environment repository**, not a Neovim config repository.
The included `nvim/` directory is one component alongside the shell and tool
environment. Clone the whole repository into your own home directory and run
one bootstrap command. No administrative privileges are needed.

## Repository structure

```text
dev-environment/
├── bootstrap.sh          # Orchestrates the entire environment
├── conda/
│   └── packages.txt     # Neovim, Node, Zsh and other private tools
├── shell/
│   ├── zshrc            # Oh My Zsh and selected plugins
│   └── dev-zsh          # Start Zsh without changing login shell
└── nvim/
    ├── init.lua         # Original NvChad v2.5 configuration
    ├── lazy-lock.json   # Original plugin version lockfile
    ├── lua/             # Original mappings, plugins and LSP config
    ├── README.md
    └── LICENSE
```

The `nvim/` subtree contains the configuration provided with this project,
including its own modified Lua settings. It has no nested `.git` directory or
Git submodule dependency. The entire tree can be tracked in **one Git repo**.

## Install on a new Linux server

Git deliberately does not run arbitrary scripts as a side effect of `git clone`.
The one-time explicit command is therefore necessary:

```bash
git clone YOUR_GIT_URL "$HOME/dev-environment"
bash "$HOME/dev-environment/bootstrap.sh"
"$HOME/.local/bin/dev-zsh"
```

Replace `YOUR_GIT_URL` with the URL of the Git repository you publish. From
inside the configured Zsh, run `nvim` to use the bundled NvChad config.

To preview first:

```bash
bash "$HOME/dev-environment/bootstrap.sh" --dry-run
```

To postpone the initial Neovim plugin downloads:

```bash
bash "$HOME/dev-environment/bootstrap.sh" --skip-nvim-sync
```

Rerunning `bootstrap.sh` reuses installations, checks whether the Conda package
list or Neovim plugin configuration changed, and installs missing components.
Changes to `shell/zshrc` are picked up through a managed symlink after `git pull`.

## Components and installation paths

Everything below stays under the **current user's `$HOME`**.

| Component | Private installation location |
|---|---|
| Miniconda 26.7.1, SHA-256 checked | `~/.local/opt/miniconda3` |
| Neovim 0.11.x, Node.js 22/npm, Zsh, Git, ripgrep, fd, Tree-sitter CLI, Stylua, rust-analyzer, compilers | `~/.local/opt/nvchad-tools` |
| `trzsz` tools (`trz`, `tsz`) | Inside `nvchad-tools` |
| Python, Bash, HTML/CSS language servers | `~/.local/share/nvchad-bootstrap/npm` |
| Lua language server | Neovim's private Mason directory |
| Oh My Zsh and zsh-autosuggestions | `~/.local/share/nvchad-bootstrap/oh-my-zsh` |
| Private Zsh profile | `~/.local/share/nvchad-bootstrap/zdot/.zshrc` → `shell/zshrc` |
| NvChad configuration | `~/.config/nvim` → this repo's `nvim/` |
| Command shortcuts | `~/.local/bin` |

The Zsh configuration enables these Oh My Zsh plugins:

```zsh
plugins=(sudo vi-mode git zsh-autosuggestions)
```

The `sudo` **shell plugin** is only an interactive keybinding; the installer does
not execute `sudo`.

## Safety and compatibility

- **No `sudo`, `apt`, `chsh`, `/usr/local` writes, or `conda init`.** The default
  SSH login shell and shared settings are left unchanged.
- An existing unrelated `~/.config/nvim` causes a clear error rather than being
  overwritten. Existing `~/.zshrc` and `~/.local/bin` entries are preserved.
- All network installs are obtained from Anaconda, conda-forge, npm, PyPI,
  GitHub, and the Mason registry. The Miniconda installer is checksum-verified.
- Linux `x86_64` and `aarch64` are supported. Old GNU libc versions can block
  current Conda binaries; restricted HPC login nodes may need approved proxies.
- `trz` and `tsz` require a compatible client-side SSH terminal integration.
- The first run can download large native packages and compile Neovim plugins.
  Existing installations are normally reused on later invocations.
- If you move the repository, run the bootstrap script again after resolving
  the existing `~/.config/nvim` symlink and managed Zsh profile links.

To leave your login shell untouched while using this environment, start each
session with:

```bash
"$HOME/.local/bin/dev-zsh"
```

If an install step fails because of network access, rerun `bootstrap.sh` after
restoring connectivity. Check Neovim Mason failures with `:MasonLog`.

## Put this directory in your own Git remote

After extracting the complete repository ZIP, run:

```bash
cd dev-environment
git init -b main
git add .
git commit -m "Initial private development environment"
git remote add origin YOUR_GIT_URL
git push -u origin main
```

You can then clone that remote on any compatible new server with the commands
above. The original `nvim/` files are committed directly as a subtree, not as a
separate repository.

## Lightweight checks

```bash
bash -n bootstrap.sh
bash -n shell/dev-zsh
bash bootstrap.sh --dry-run
```
