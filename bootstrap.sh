#!/usr/bin/env bash
# Home-only, repeatable setup for the complete development environment repo.
set -Eeuo pipefail
umask 077

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
NVIM_SOURCE="$PROJECT_DIR/nvim"
USER_HOME="${HOME:?HOME must be set}"
DATA_DIR="$USER_HOME/.local/share/nvchad-bootstrap"
OPT_DIR="$USER_HOME/.local/opt"
BIN_DIR="$USER_HOME/.local/bin"
CONDA_DIR="$OPT_DIR/miniconda3"
TOOLS_DIR="$OPT_DIR/nvchad-tools"
NPM_DIR="$DATA_DIR/npm"
ZDOT_DIR="$DATA_DIR/zdot"
OMZ_DIR="$DATA_DIR/oh-my-zsh"
NVIM_CONFIG="$USER_HOME/.config/nvim"
MARKER="$DATA_DIR/nvim-sync.sha256"
PKG_MARKER="$DATA_DIR/conda-packages.sha256"
DRY_RUN=0
SKIP_NVIM_SYNC=0

say() { printf '[bootstrap] %s\n' "$*"; }
warn() { printf '[bootstrap] WARNING: %s\n' "$*" >&2; }
die() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  printf '%s\n' 'Usage: bash bootstrap.sh [--dry-run] [--skip-nvim-sync]' \
    '' \
    'Linux x86_64/aarch64. Install this repository as one private HOME environment.' \
    'Never runs sudo, apt, chsh or conda init.'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-nvim-sync) SKIP_NVIM_SYNC=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "Unknown argument: $arg" ;;
  esac
done

[[ "$(uname -s)" == "Linux" ]] || die 'Only Linux servers are supported.'
case "$(uname -m)" in
  x86_64|aarch64) ARCH="$(uname -m)" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac
[[ "$USER_HOME" == /* ]] || die 'HOME must be an absolute path.'
[[ -f "$NVIM_SOURCE/init.lua" && -f "$NVIM_SOURCE/lazy-lock.json" ]] ||
  die 'The environment repo must contain nvim/init.lua and nvim/lazy-lock.json.'

# Anaconda's published SHA-256 hashes for the immutable 26.7.1 installers.
case "$ARCH" in
  x86_64)
    INSTALLER='Miniconda3-py312_26.7.1-0-Linux-x86_64.sh'
    INSTALLER_SHA='3d33f72fcb35134ab68a7775021a0ee6d22b8a4dd9139d9c9798792e933ee132'
    ;;
  aarch64)
    INSTALLER='Miniconda3-py312_26.7.1-0-Linux-aarch64.sh'
    INSTALLER_SHA='391edcfaef0e70b7047834a86e48f5686eb0fe1e7612a086ca73e0084ffea45f'
    ;;
esac

if (( DRY_RUN )); then
  say "Project: $PROJECT_DIR"
  say "Neovim module: $NVIM_SOURCE"
  say "Architecture: Linux $ARCH"
  say "Miniconda: $CONDA_DIR (verified $INSTALLER)"
  say "User tools: $TOOLS_DIR (Neovim 0.11, Node/npm, Zsh, LSP, etc.)"
  say "NvChad: $NVIM_CONFIG -> $NVIM_SOURCE"
  say "Oh My Zsh + isolated config: $DATA_DIR"
  say "trzsz: installed into the user tools environment"
  say "Shell entrypoint: $BIN_DIR/dev-zsh (no chsh)"
  (( SKIP_NVIM_SYNC )) && say 'Initial Lazy plugin sync: skipped'
  exit 0
fi

[[ "$(id -u)" != 0 ]] || die 'Do not run the installer as root.'

command -v git >/dev/null || die 'git is required to clone the repository and plugins.'
command -v tar >/dev/null || die 'tar is required.'
command -v curl >/dev/null || command -v wget >/dev/null ||
  die 'curl or wget is required to download Miniconda.'
command -v sha256sum >/dev/null || command -v shasum >/dev/null ||
  die 'sha256sum or shasum is required for installer verification.'

# Fail before downloads if a different Neovim configuration already exists.
if [[ -e "$NVIM_CONFIG" || -L "$NVIM_CONFIG" ]]; then
  EXISTING="$(cd -P -- "$NVIM_CONFIG" 2>/dev/null && pwd -P || true)"
  [[ "$EXISTING" == "$NVIM_SOURCE" ]] ||
    die "$NVIM_CONFIG already exists and is not this repository. Move/backup it yourself first."
fi
for path in "$USER_HOME/.local" "$USER_HOME/.local/share" "$OPT_DIR" \
            "$BIN_DIR" "$DATA_DIR" "$NPM_DIR" "$ZDOT_DIR" \
            "$USER_HOME/.config" "$CONDA_DIR" "$TOOLS_DIR" "$OMZ_DIR"; do
  [[ ! -L "$path" ]] || die "Refusing a symlink at managed install target: $path"
done

mkdir -p "$DATA_DIR" "$OPT_DIR" "$BIN_DIR" "$ZDOT_DIR" "$USER_HOME/.config"

fetch() {
  local url="$1" output="$2"
  if command -v curl >/dev/null; then
    curl --fail --location --retry 3 --connect-timeout 15 --output "$output" "$url"
  else
    wget --tries=3 --timeout=30 --output-document="$output" "$url"
  fi
}

check_sha() {
  local archive="$1" expected="$2" actual
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$archive")"
  else
    actual="$(shasum -a 256 "$archive")"
  fi
  [[ "${actual%% *}" == "$expected" ]] ||
    die "Miniconda checksum mismatch. Not executing installer: $archive"
}

install_conda() {
  if [[ -x "$CONDA_DIR/bin/conda" ]]; then
    say 'Miniconda already installed; reusing it.'
    return
  fi
  [[ ! -e "$CONDA_DIR" ]] ||
    die "Incomplete Miniconda directory at $CONDA_DIR; inspect it before retrying."
  local tmp installer_path
  tmp="$(mktemp -d "$DATA_DIR/miniconda.XXXXXXXX")"
  installer_path="$tmp/$INSTALLER"
  say "Downloading verified $INSTALLER ..."
  fetch "https://repo.anaconda.com/miniconda/$INSTALLER" "$installer_path"
  check_sha "$installer_path" "$INSTALLER_SHA"
  bash "$installer_path" -b -p "$CONDA_DIR"
  # Installer file is temporary; the installation itself remains under HOME.
  rm -f -- "$installer_path"
  rmdir -- "$tmp" 2>/dev/null || true
}

read_packages() {
  PACKAGES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    PACKAGES+=("$line")
  done < "$PROJECT_DIR/conda/packages.txt"
  (( ${#PACKAGES[@]} > 0 )) || die 'No packages specified.'
}

install_tools() {
  read_packages
  local conda="$CONDA_DIR/bin/conda"
  export CONDA_PKGS_DIRS="$DATA_DIR/conda-pkgs"
  mkdir -p "$CONDA_PKGS_DIRS"
  local complete=1 cmd package_digest
  if command -v sha256sum >/dev/null; then
    package_digest="$(sha256sum "$PROJECT_DIR/conda/packages.txt")"
  else
    package_digest="$(shasum -a 256 "$PROJECT_DIR/conda/packages.txt")"
  fi
  package_digest="${package_digest%% *}"
  for cmd in nvim node npm zsh rg fd tree-sitter stylua rust-analyzer python; do
    [[ -x "$TOOLS_DIR/bin/$cmd" ]] || complete=0
  done
  if (( complete )) && [[ -f "$PKG_MARKER" && "$(< "$PKG_MARKER")" == "$package_digest" ]]; then
    say 'Conda package manifest unchanged; skipping package solve.'
    return
  fi
  if [[ -d "$TOOLS_DIR/conda-meta" ]]; then
    say 'Repairing an incomplete Conda tools environment ...'
    "$conda" install -y -p "$TOOLS_DIR" --override-channels -c conda-forge "${PACKAGES[@]}"
  else
    [[ ! -e "$TOOLS_DIR" ]] || die "Unexpected directory at $TOOLS_DIR"
    say 'Creating isolated Conda tools environment ...'
    "$conda" create -y -p "$TOOLS_DIR" --override-channels -c conda-forge "${PACKAGES[@]}"
  fi
  printf '%s\n' "$package_digest" > "$PKG_MARKER"
}

install_omz() {
  if [[ -f "$OMZ_DIR/oh-my-zsh.sh" ]]; then
    say 'Oh My Zsh already present; reusing it.'
  elif [[ -e "$OMZ_DIR" ]]; then
    die "Incomplete Oh My Zsh directory: $OMZ_DIR"
  else
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
  fi
  local auto="$OMZ_DIR/custom/plugins/zsh-autosuggestions"
  if [[ -f "$auto/zsh-autosuggestions.plugin.zsh" ]]; then
    say 'zsh-autosuggestions already present.'
  elif [[ -e "$auto" ]]; then
    die "Incomplete zsh-autosuggestions directory: $auto"
  else
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$auto"
  fi
}

install_trzsz() {
  local py="$TOOLS_DIR/bin/python"
  if [[ -x "$TOOLS_DIR/bin/trz" && -x "$TOOLS_DIR/bin/tsz" ]]; then
    say 'trzsz already present.'
  else
    "$py" -m pip install --disable-pip-version-check --no-input 'trzsz>=1.1,<2'
  fi
}

install_node_servers() {
  export PATH="$TOOLS_DIR/bin:$PATH"
  if [[ -x "$NPM_DIR/bin/pyright-langserver" &&
        -x "$NPM_DIR/bin/bash-language-server" &&
        -x "$NPM_DIR/bin/vscode-html-language-server" ]]; then
    say 'Node language servers already present.'
    return
  fi
  mkdir -p "$NPM_DIR"
  "$TOOLS_DIR/bin/npm" install --global --prefix "$NPM_DIR" --no-audit --no-fund \
    'pyright@^1' 'bash-language-server@^5' 'vscode-langservers-extracted@^4'
}

safe_link() {
  local source="$1" target="$2"
  [[ -e "$source" ]] || { warn "Source not installed, not linking: $source"; return; }
  if [[ -L "$target" ]]; then
    [[ "$(readlink "$target")" == "$source" ]] ||
      warn "Keeping existing link: $target"
  elif [[ -e "$target" ]]; then
    warn "Keeping existing file: $target"
  else
    ln -s -- "$source" "$target"
  fi
}

install_launchers() {
  local binary
  for binary in conda; do
    safe_link "$CONDA_DIR/bin/$binary" "$BIN_DIR/$binary"
  done
  for binary in nvim node npm npx zsh rg fd tree-sitter stylua rust-analyzer \
                trz tsz; do
    safe_link "$TOOLS_DIR/bin/$binary" "$BIN_DIR/$binary"
  done
  for binary in pyright pyright-langserver bash-language-server \
                vscode-html-language-server vscode-css-language-server; do
    safe_link "$NPM_DIR/bin/$binary" "$BIN_DIR/$binary"
  done
  # Keep the shell entrypoint even if the original Git checkout moves later.
  install -m 700 "$PROJECT_DIR/shell/dev-zsh" "$DATA_DIR/dev-zsh"
  safe_link "$DATA_DIR/dev-zsh" "$BIN_DIR/dev-zsh"
}

install_dotfiles() {
  local managed_zshrc="$ZDOT_DIR/.zshrc"
  if [[ -L "$managed_zshrc" ]]; then
    [[ "$(readlink "$managed_zshrc")" == "$PROJECT_DIR/shell/zshrc" ]] ||
      warn "Existing managed .zshrc link retained: $managed_zshrc"
  elif [[ -e "$managed_zshrc" ]]; then
    warn "Existing managed .zshrc file retained: $managed_zshrc"
  else
    # Track future `git pull` changes to the Zsh profile automatically.
    ln -s -- "$PROJECT_DIR/shell/zshrc" "$managed_zshrc"
  fi
  if [[ ! -e "$USER_HOME/.zshrc" && ! -L "$USER_HOME/.zshrc" ]]; then
    safe_link "$managed_zshrc" "$USER_HOME/.zshrc"
  else
    say "Existing ~/.zshrc preserved; dev-zsh always loads the managed setup."
  fi
  [[ -e "$NVIM_CONFIG" || -L "$NVIM_CONFIG" ]] ||
    ln -s -- "$NVIM_SOURCE" "$NVIM_CONFIG"
}

hash_nvim_config() {
  local info
  if command -v sha256sum >/dev/null; then
    info="$(sha256sum "$NVIM_SOURCE/lazy-lock.json" "$NVIM_SOURCE/init.lua" \
      "$NVIM_SOURCE/lua/plugins/init.lua")"
    printf '%s' "$info" | sha256sum | cut -d' ' -f1
  else
    info="$(shasum -a 256 "$NVIM_SOURCE/lazy-lock.json" "$NVIM_SOURCE/init.lua" \
      "$NVIM_SOURCE/lua/plugins/init.lua")"
    printf '%s' "$info" | shasum -a 256 | cut -d' ' -f1
  fi
}

sync_nvim() {
  (( SKIP_NVIM_SYNC )) && { warn 'Skipped initial Lazy plugin sync by request.'; return; }
  local digest
  digest="$(hash_nvim_config)"
  if [[ -f "$MARKER" && "$( < "$MARKER")" == "$digest" &&
        -d "$USER_HOME/.local/share/nvim/lazy/NvChad" ]]; then
    say 'NvChad plugin lockfile unchanged; skipping Lazy sync.'
    return
  fi
  say 'Installing/synchronizing pinned NvChad plugins (Lazy.nvim) ...'
  export PATH="$NPM_DIR/bin:$TOOLS_DIR/bin:$BIN_DIR:$PATH"
  export XDG_CONFIG_HOME="$USER_HOME/.config"
  # Lazy!'s bang form waits for the operation before quitting.
  "$CONDA_DIR/bin/conda" run --no-capture-output -p "$TOOLS_DIR" \
    nvim --headless '+Lazy! sync' '+qa' ||
    die 'NvChad Lazy sync failed. Check network/compiler logs; rerun after correcting the issue.'
  printf '%s\n' "$digest" > "$MARKER"
}

install_lua_lsp() {
  # NvChad's built-in Lua LSP defaults enable lua_ls. Its server is normally
  # supplied through Mason, not the available Linux conda-forge packages.
  local lsp="$USER_HOME/.local/share/nvim/mason/bin/lua-language-server"
  if [[ -e "$lsp" ]]; then
    say 'Lua language server already present in Mason.'
    return
  fi
  (( SKIP_NVIM_SYNC )) && return
  say 'Installing Lua language server via NvChad Mason ...'
  export PATH="$NPM_DIR/bin:$TOOLS_DIR/bin:$BIN_DIR:$PATH"
  export XDG_CONFIG_HOME="$USER_HOME/.config"
  # Explicitly load Mason because NvChad may load it only upon an editor command.
  # MasonInstall blocks in Neovim headless mode (Mason's documented behavior).
  "$CONDA_DIR/bin/conda" run --no-capture-output -p "$TOOLS_DIR" \
    nvim --headless \
    '+lua require("lazy").load({plugins={"mason.nvim"}})' \
    '+MasonInstall lua-language-server' '+qa' ||
    die 'Mason Lua language-server installation failed. Fix the reported error and rerun bootstrap.'
  [[ -e "$lsp" ]] || die 'Mason returned without installing lua-language-server; inspect :MasonLog.'
}

say 'Starting home-only environment setup.'
install_conda
install_tools
# Independent network operations may proceed concurrently.
install_omz &
omz_pid=$!
install_node_servers &
node_pid=$!
wait "$omz_pid" || die 'Oh My Zsh installation failed.'
wait "$node_pid" || die 'Node language server installation failed.'
install_trzsz
install_dotfiles
install_launchers
sync_nvim
install_lua_lsp

say 'Setup complete. No sudo/chsh/apt/conda-init commands were run.'
say "Start configured Zsh: $BIN_DIR/dev-zsh"
say "Neovim binary: $TOOLS_DIR/bin/nvim"
say "Miniconda binary: $CONDA_DIR/bin/conda"
say "If needed in current bash: export PATH=\"$BIN_DIR:$NPM_DIR/bin:$TOOLS_DIR/bin:\$PATH\""
