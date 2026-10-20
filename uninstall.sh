#!/bin/sh
# Star Wolves 3 mods: uninstall. Same options as install.sh; see ./uninstall.sh --help.
SW3_ACTION=uninstall exec "$(cd "$(dirname "$0")" && pwd)/install.sh" "$@"
