#!/usr/bin/env bash

# This file contains Bash helper functions to aid in composing development,
# build, pipeline, and deployement scripts.

BIN_DIR="$(dirname -- "$0")"

# Wrapper around jq to work with XML and YAML too
OQ="${BIN_DIR}/utils/oq"

OQ_SUCCESS="Command '${OQ}' is available"

# Wrapper around installing system packages
PACAPT="${BIN_DIR}/utils/pacapt"

export BIN_DIR OQ PACAPT


# shecllcheck source=bin/utils/messages.sh
source "${BIN_DIR}/utils/messages.sh"


# Prompt the user for confirmation. A custom message can be provided.
_confirm() {
  local prompt_string=${1:-"Are you sure?"}

  echo
  read -r -p "${prompt_string} [Y/n] " response
  case "$response" in
    [yY][eE][sS]|[yY]|"")
      true
      ;;
    *)
      false
      ;;
  esac
}


# Use PACAPT to install the providied system package
_install_package() {
  local package_name="${1?}"
  "${PACAPT}" install "${package_name}"
}


# If the command_name ($1) is not installed prompt to install package ($2)
# package defaults to command_name if not provided
_prompt_for_command_install() {
  local command_name=${1?}
  local package=${2:$1}
  local prompt_message="System package '${package}' is required. Would you like to install it now?"

  if ! command -v "${command_name}" >/dev/null; then
    if _confirm "${prompt_message}"; then
      _info_message "Installing ${package}"
      _install_package "${package}"
      _success_message "Success - the command ${command_name} is now available"
    else
      _info_message "Things may not work properly without this, but moving on."
    fi
  else
    _success_message "Command ${command_name} is available"
  fi
}

_install_oq() {
  # Install via homebrew if available
  if command -v brew >/dev/null; then
    brew tap blacksmoke16/tap
    _info_message "Installing oq via Homebrew"
    brew install oq
    ln -s "$(which oq)" "${OQ}"
  else
    _info_message "Installing oq via curl download"
    curl -sL \
      "https://github.com/Blacksmoke16/oq/releases/download/v${OQ_VERSION}/oq-v${OQ_VERSION}-linux-x86_64" \
      > "${OQ}"
    chdmod a+x "${OQ}"
  fi
}

_prompt_for_oq_install() {
  local command_name="oq"
  local package="oq"
  local prompt_message="System package '${package}' is required. Would you like to install it now?"

  # If we already have a valid symlinked command - we're good
  if command -v "${OQ}"; then
    _success_message "${OQ_SUCCESS}"

  # If oq is already installed, symlink it now
  elif oq_command=$(command -v "${command_name}"); then
    ln -s "${oq_command}" "${OQ}"
    _success_message "${OQ_SUCCESS}"

  # Not installed
  elif _confirm "${prompt_message}"; then
    _install_oq
    _success_message "Success - the command ${OQ} is now available"

  else
    _info_message "Things may not work properly without this, but moving on."
  fi
}
