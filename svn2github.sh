## Include files in the current working directory
INC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
source ${INC_DIR}/_functions.sh

_welcome
_setup
_svn_sizer
_discover_submodules
_git_svn_clone
# Don't process submodules first... it will change the processing of the parent
_process_submodules

(
  cd ${REPO_NAME}
  git config http.sslVerify false
  _prepare_github
  _migrate_trunk
  _migrate_tags
  _migrate_branches
)

_cleanup
