## Include files in the current working directory
INC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
source ${INC_DIR}/_functions.sh

_cleanup
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
