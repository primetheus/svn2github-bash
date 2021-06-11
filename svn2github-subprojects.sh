#!/usr/bin/env bash
## Include files in the current working directory
if [[ $(uname) != 'Linux' ]]
then
  source _functions.sh
else
  INC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
  [[ -f "${INC_DIR}/_functions.sh" ]] && source "${INC_DIR}/_functions.sh"
fi

_welcome
_setup
[[ "${SVN_SIZER,,}" == "true" ]] && _svn_sizer
## Process sub-projects
[[ ! -d /tmp/submodules.txt ]] && echo "Please add projects to /tmp/submodules.txt" && exit 0
_process_submodules

_cleanup
