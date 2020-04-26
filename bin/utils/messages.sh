#!/usr/bin/env bash

# ------------------------------------------------------------------------
# Messages
# ------------------------------------------------------------------------

red=$'\e[1;31m'
green=$'\e[1;32m'
#blue=$'\e[1;34m'
magenta=$'\e[1;35m'
#cyan=$'\e[1;36m'
end=$'\e[0m'

# Print a fenced message in color
#
# Usage: color_banner message [message_color=$magenta] [end_color=$end]
#
# Examples:
#   color_banner "You've done it! Success!" "${green}"
#
#   color_banner "Doh! Something failed." "${red}"
#
_color_banner() {
  local message=${1?}
  local message_color="${2:-$magenta}"
  local end_color="${3:-$end}"
  local fence="======================================================="

  printf "\n%s%s%s" "${message_color}" "${fence}" "${end_color}"
  printf "\n%s  %s%s" "${message_color}" "${message}" "${end_color}"
  printf "\n%s%s\n\n%s" "${message_color}" "${fence}" "${end_color}"
}


# Print a single line message in color
#
# Usage: color_message [message_color=$magenta] [end_color=$end]
#
# Examples:
#   color_message "Checking for dependency"
#
#   color_message "Dependency check failed" "${red}"
_color_message() {
  local message=${1?}
  local message_color="${2:-$magenta}"
  local end_color="${3:-$end}"

  printf "%s* %s%s\n" "${message_color}" "${message}" "${end_color}"
}

_info_banner() { _color_banner "${1}" "${magenta}"; }
_success_banner() { _color_banner "${1}" "${green}"; }
_error_banner() { _color_banner "${1}" "${red}"; }

_info_message() { _color_message "${1}" "${magenta}"; }
_success_message() { _color_message "${1}" "${green}"; }
_error_message() { _color_message "${1}" "${red}"; }
