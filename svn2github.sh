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
_discover_submodules
_process_submodules
_git_svn_clone
(
  cd ${REPO_NAME}
  git config http.sslVerify false
  _prepare_github
  _migrate_trunk
  _add_git_submodules
  _migrate_tags
  _migrate_branches
)
_cleanup
