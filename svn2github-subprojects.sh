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
[[ ! -f /tmp/projects.txt ]] && echo "Please add projects to /tmp/projects.txt" && exit 0
export SUBMODULES=$(cat /tmp/projects.txt)
_process_submodules

_cleanup
