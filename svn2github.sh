#!/usr/bin/env bash
## Include files in the current working directory
if [[ $(uname) != 'Linux' ]]
then
  source _functions.sh
else
  INC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
  [[ -f ${INC_DIR}/_functions.sh ]] && source ${INC_DIR}/_functions.sh
fi

_welcome
_setup
_svn_sizer
## Process submodules
if [[ ${ENABLE_SUBMODULES} ]]
then
  _discover_submodules
  _process_submodules
else
  _get_svn_layout
fi
## Perform a clean cutover or migrate history
if [[ ${MIGRATE_HISTORY} ]]
then
  _git_svn_clone
else
  _clean_cutover
fi
## Migrate trunk, branches, tags, submodules
(
  cd ${REPO_NAME}
  git config http.sslVerify false
  _prepare_github
  _migrate_trunk
  [[ ${ENABLE_SUBMODULES} ]] && _add_git_submodules
  _migrate_tags
  _migrate_branches
)
_cleanup
