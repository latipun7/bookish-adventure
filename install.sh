#!/usr/bin/env bash
# -*-shell-script-*- vim:syntax=shell-script
# code:language=shellscript
# shellcheck disable=SC2154
#
# Install Dependencies and Dotfiles

set -euo pipefail

esc="\033"
reset="${esc}[0m"

# 256 Colors Foreground
for color in {0..255}; do
  declare "color${color}=${esc}[38;5;${color}m"
done

# 256 Colors Background
for bg in {0..255}; do
  declare "bg${bg}=${esc}[48;5;${bg}m"
done

function print_help() {
  echo
}

function die() {
  local _ret="${2:-1}"
  if [[ $_ret != 0 ]]; then
    test "${_PRINT_HELP:-no}" = yes && print_help >&2
    echo -e "$1" >&2
  else
    test "${_PRINT_HELP:-no}" = yes && print_help
    echo -e "$1"
  fi

  exit "${_ret}"
}

function info() {
  echo -e "\n${color14}==>${reset} $1 ℹ\n"
}

function step() {
  echo -e "\n${color13}==>${reset} $1 👟\n"
}

function success() {
  echo -e "\n${color2}==>${reset} $1 ✔\n"
}

function fail() {
  die "\n${color1}==>${reset} $1 ❌\n" 1
}

#===================================================0

function check_dependencies() {
  step "Checking dependencies for the installation script..."

  if ! hash curl 2>/dev/null; then
    fail "Missing ${color6}curl${reset}!\n    Not installing due to missing dependencies."
  fi

  if ! hash gzip 2>/dev/null; then
    fail "Missing ${color6}gzip${reset}!\n    Not installing due to missing dependencies."
  fi

  if ! hash chezmoi 2>/dev/null; then
    fail "Missing ${color6}chezmoi${reset}!\n    Not installing due to missing dependencies."
  fi

  info "OK!"
}

function get_fnm_url() {
latest_url='https://github.com/Schniz/fnm/releases/latest/download'

if [[ "$(uname -s)" == *Linux* ]]; then
  case "$(uname -m)" in
    arm | armv7*)
      URL="$latest_url/fnm-arm32.zip"
      ;;
    aarch* | armv8*)
      URL="$latest_url/fnm-arm64.zip"
      ;;
    *)
      URL="$latest_url/fnm-linux.zip"
  esac
fi

if [[ "$(uname -s)" == *Darwin* ]]; then
  USE_HOMEBREW="true"
fi
}

function install_fnm() {
  step "Install ${color6}fnm${reset}"

  if [ "${USE_HOMEBREW:-no}" = "true" ]; then
    if hash brew 2>/dev/null; then
      step "Brewing ${color6}fnm${reset} ..."
      brew install fnm
    else
      fail "Missing ${color6}brew${reset}!\n    Not installing due to missing dependencies."
    fi
  else
    check_dependencies

    DOWNLOAD_DIR="$(mktemp -dp /tmp "fnm-XXXXX")"
    INSTALL_DIR="$HOME/.local/bin"

    mkdir -p "$INSTALL_DIR"

    step "Downloading $URL ..."

    if ! curl --progress-bar -fsLSo "$DOWNLOAD_DIR/fnm.zip" "$URL"; then
      fail "Download ${color6}fnm${reset} failed. Check that the release/filename are correct."
    fi

    gzip -dS .zip "$DOWNLOAD_DIR/fnm.zip"

    if [ -f "$DOWNLOAD_DIR/fnm" ]; then
      mv "$DOWNLOAD_DIR/fnm" "$INSTALL_DIR/fnm"
    else
      mv "$DOWNLOAD_DIR/fnm/fnm" "$INSTALL_DIR/fnm"
    fi

    chmod +x "$INSTALL_DIR/fnm"

    if ! ( echo "$PATH" | grep -q '/.local/bin:' ); then
      export PATH=$INSTALL_DIR:$PATH
    fi

    rm -rf "$DOWNLOAD_DIR" # clean temp directory
  fi

  DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
  mkdir -p "$DATA_DIR"
  export FNM_DIR=$DATA_DIR
}

get_fnm_url
install_fnm
hash fnm &>/dev/null && eval "$(fnm env --use-on-cd)"

step "Install latest LTS nodeJS..."
fnm install --lts && fnm use 'lts/*'

step "Install global node modules..."

export npm_config_cache="$HOME/.cache/npm"
corepack enable
npm install -gq @bitwarden/cli pm2

success "${color6}fnm${reset}, ${color6}node${reset}, ${color6}bitwarden${reset}, and ${color6}pm2${reset} already installed!"

# login and unlock `bw`, if already login, unlock if not unlocked yet.
if bw login; then
  eval "$(bw unlock | grep -oE --color=never "(export BW_SESSION=".+")")"
else
  if ! (env | grep -q 'BW_SESSION'); then
    eval "$(bw unlock | grep -oE --color=never "(export BW_SESSION=".+")")"
  fi
fi

# Bootstrap dotfiles
step "Install dotfiles..."
chezmoi init --apply -v
success "All done 👏"
