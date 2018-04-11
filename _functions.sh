function _setup()
{
  ## Git-SVN has issues on Mac... don't try it. Just use Docker or a VM
  [[ $(uname) != 'Linux' ]] && echo "Sorry, this works only with Linux" && exit 1
  ## If we have a settings file, use it to bypass input
  INC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
  [[ -f ${INC_DIR}/settings.ini ]] && source ${INC_DIR}/settings.ini
  rm -f /tmp/{submodules,github_remotes}.txt
  ## If there's no settings file, ask for input
  ## This can be stored your the environment as well
  while [ -z ${REPOSITORY} ];do
    [[ -z ${REPOSITORY} ]] && read -p "Please specify an SVN Repository: " REPOSITORY
    export REPOSITORY # exporting so it's callable outside of this function
  done
  while [ -z ${GITHUB_URL} ];do
    [[ -z ${GITHUB_URL} ]] && read -p "Please specify a URL for GitHub (i.e. https://github.mycompany.com): " GITHUB_URL
    export GITHUB_URL # exporting so it's callable outside of this function
  done
  while [ -z ${GITHUB_ORG} ];do
    [[ -z ${GITHUB_ORG} ]] && read -p "Please specify an Organization to place these repositories in: " GITHUB_ORG
    export GITHUB_ORG # exporting so it's callable outside of this function
  done
  while [ -z ${GITHUB_TOKEN} ];do
    [[ -z ${GITHUB_TOKEN} ]] && echo -n "Please provide a Personal Access Token that can create repositories in ${GITHUB_ORG}: ";read -s GITHUB_TOKEN
    export GITHUB_TOKEN # exporting so it's callable outside of this function
    echo ""
  done
  [[ ! -z ${AUTHORS_FILE} ]] && AUTHORS=" --authors-file=${AUTHORS_FILE}"
  github_machine=$(echo ${GITHUB_URL}|awk -F'//' {'print $2'})
  svn_machine=$(echo ${REPOSITORY}|awk -F'/' {'print $3'})
  cat > ~/.netrc <<EOF
machine ${github_machine}
  login token
  password ${GITHUB_TOKEN}

machine ${svn_machine}
  login ${SVN_USERNAME}
  password ${SVN_PASSWORD}
EOF
  ## Set our default SVN options
  SVN_OPTIONS="--trust-server-cert --non-interactive --no-auth-cache --username ${SVN_USERNAME} --password ${SVN_PASSWORD}"
  ## Get the repo name and full URL for the remote subversion repository
  REPO_NAME=$(svn info ${REPOSITORY} ${SVN_OPTIONS}|grep '^Path'|awk {'print $2'}|sed 's/ /-/g')
  REPO_URL=$(svn info ${REPOSITORY} ${SVN_OPTIONS}|grep '^URL'|awk {'print $2'})
  SVN_HEAD=$(svn info ${REPOSITORY} ${SVN_OPTIONS}|grep '^Revision'|awk {'print $2'})
  ## Set the log file, if we don't have an explicit file configured
  [[ -z ${LOG_FILE} ]] && LOG_FILE=/tmp/svn2github-${REPO_NAME}.log
}

## Get some info about the remote repository
function _svn_sizer()
{
  _print_banner "Discovering repository size"
  svn list ${SVN_OPTIONS} -vR ${REPO_URL}|awk '{if ($3 !="") sum+=$3; i++} END {print "\nTotal Size: " sum/1024000" MB" "\nNumber of Files: " i/1000 " K"}'
}

## Format a banner
function _print_banner()
{
  local s=("$@") b w
  for l in "${s[@]}"; do
    ((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo "####${b//?/#}####
##  ${b//?/ }  ##"
  for l in "${s[@]}"; do
    printf '##  %s%*s%s  ##\n' "$(tput setaf 4)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "##  ${b//?/ }  ##
####${b//?/#}####"
  tput sgr 0
}

function _welcome()
{
  _print_banner "Welcome to the Subversion to GitHub migrator" \
    "utility! This utility is intended for use by" \
    "experienced systems administrators, as there" \
    "may be errors encountered with certain repo" \
    "layouts. This tools comes with no warranty," \
    "expressed or implied, and may be modified" \
    "by anyone who sees fit to do so, in any way" \
    "they see fit, with no reprocussions whatsoever"
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

## Create a repository in GitHub
function _prepare_github()
{
  echo "Creating ${REPO_NAME} in GitHub..."
  curl -skH "Authorization: token ${GITHUB_TOKEN}" \
    ${GITHUB_URL}/api/v3/orgs/${GITHUB_ORG}/repos \
    -d '{"name":"'"${REPO_NAME}"'"}' &>> ${LOG_FILE}
}

## Migrate trunk to master
function _migrate_trunk()
{
  echo "Migrating Trunk to Master..."
  git remote add github ${GITHUB_URL}/${GITHUB_ORG}/${REPO_NAME}.git &>> ${LOG_FILE}
  if [[ $(git branch -a|grep 'remotes/svn/trunk') ]]
  then
    echo "git checkout -b master remotes/svn/trunk" &>> ${LOG_FILE}
    git checkout -B master remotes/svn/trunk
    git push --set-upstream github master &>> ${LOG_FILE}
  else
    git push github --mirror &>> ${LOG_FILE}
  fi
}

## Migrate all tags
function _migrate_tags()
{
  echo "Migrating Tags..."
  git for-each-ref refs/remotes/svn/tags|cut -d / -f5-|while read ref
  do
    git tag -a "${ref}" -m"SVN to GitHub Migration" "refs/remotes/svn/tags/${ref}" &>> ${LOG_FILE}
    git push github ":refs/heads/tags/${ref}" &>> ${LOG_FILE}
    git push github tag "${ref}" &>> ${LOG_FILE}
  done
}

## Migrate all branches, except "trunk"
function _migrate_branches()
{
  echo "Migrating Branches..."
  for branch in $(git branch -a|grep svn|grep -v '/tags/'|grep -v 'remotes/svn/trunk')
  do
      github_branch=$(echo ${branch}|awk -F'/' {'print $NF'})
      echo "git checkout -b ${github_branch} ${branch}" &>> ${LOG_FILE}
      git checkout -B ${github_branch} ${branch} &>> ${LOG_FILE}
      _initialize_lfs &>> ${LOG_FILE}
      git push --set-upstream github ${github_branch} &>> ${LOG_FILE}
  done
}

## Iterate through the remote repository and
## find potential remote repositories
function _discover_submodules()
{
  unset IGNORE_DIRS SUBMODULES ACTIONS SELECTION SUBDIRS choices options MENU FLAGS
  _get_svn_layout
  clear
  echo "Discovering potential submodule candidates..."
  # Get the potential list of submodules, with branches, tags and trunk
  svn -R list ${REPO_URL} ${SVN_OPTIONS}|grep -E '(/trunk/$|/branches/$|/tags/$)' > /tmp/submodules.txt
  # Remove empty "trunk", "tags" and "branches" from the list of potentials
  for DIR in $(cat submodules.txt);
  do
    FILES=$(svn list ${REPO_URL}/${DIR} ${SVN_OPTIONS})
    if [[ ${#FILES} -le 1 ]]
    then
      sed -i "s/${DIR}/d" /tmp/submodules.txt
    fi
  done
  # Get the path to the submodules
  export SUBMODULES=$(grep -E '(/trunk/$|/branches/$|/tags/$)' /tmp/submodules.txt|\
  sed -e 's/trunk\/$//' -e 's/tags\/$//' -e 's/branches\/$//'|sort|uniq)

  # Print a report of the discovered submodules
  if [[ ${#SUBMODULES} -le 4 ]]
  then
    echo "There were no nested repositories discovered"
  else
    options=($(echo ${SUBMODULES}))
    #Actions to take based on selection
    function ACTIONS {
      for NUM in ${!options[@]}; do
        [[ ${choices[NUM]} ]] && SUBDIRS+="${options[NUM]} "
      done
      if [[ ! -z ${SUBDIRS} ]]
      then
        export IGNORE_DIRS=$(echo "'^("${SUBDIRS}")$'"|sed -e 's/ /|/g;s/\/|)/\/)/')
        export FLAGS+=" --ignore-paths ${IGNORE_DIRS}"
      fi
    }
    #Variables
    ERROR=" "
    #Clear screen for menu
    clear
    #Menu function
    function MENU {
      _print_banner "We have discovered the following folders that contain" \
        "branches, tags, or trunk. This typically means that teams are using" \
        "them as separate repositories, but there is no real method of" \
        "discovering this, outside of the 'svn:externals' property, which is" \
        "often not used. Please review the following folders and select which" \
        "ones are to be treated as git submodules"
        echo ""
        echo "Discovered Folders"
        for NUM in ${!options[@]}; do
          echo "[""${choices[NUM]:- }""]" $(( NUM+1 ))") ${options[NUM]}"
        done
        echo "$ERROR"
    }
    #Menu loop
    while MENU && read -e -p "Select the desired options using their number (again to uncheck, ENTER when done): " -n1 SELECTION && [[ -n "${SELECTION}" ]]; do
      clear
      if [[ "${SELECTION}" == *[[:digit:]]* && ${SELECTION} -ge 1 && ${SELECTION} -le ${#options[@]} ]]; then
        (( SELECTION-- ))
        if [[ "${choices[SELECTION]}" == "+" ]]; then
          choices[SELECTION]=""
        else
          choices[SELECTION]="+"
        fi
        ERROR=" "
      else
        ERROR="Invalid option: ${SELECTION}"
      fi
    done
    ACTIONS
  fi
}

function _get_svn_layout()
{
  unset FLAGS
  echo "Analyzing repository layout..."
  TAGS=$(svn ls ${REPO_URL} ${SVN_OPTIONS}|grep '^tags/$'|awk -F'/' {'print $(NF-1)'})
  BRANCHES=$(svn ls ${REPO_URL} ${SVN_OPTIONS}|grep '^branches/$'|awk -F'/' {'print $(NF-1)'})
  TRUNK=$(svn ls ${REPO_URL} ${SVN_OPTIONS}|grep '^trunk/$'|awk -F'/' {'print $(NF-1)'})
  ROOT_FILES=$(svn ls ${REPO_URL} ${SVN_OPTIONS}|grep -Ev '(^tags/$|^trunk/$|^branches/$)')
  [[ ! -z ${BRANCHES} ]] && [[ ! -z $(svn ls ${REPO_URL}/branches ${SVN_OPTIONS}) ]] && FLAGS+=" --branches=branches"
  [[ ! -z ${TAGS} ]] && [[ ! -z $(svn ls ${REPO_URL}/tags ${SVN_OPTIONS}) ]] && FLAGS+=" --tags=tags"
  if [[ ! -z ${TRUNK} ]] && [[ ! -z ${ROOT_FILES} ]]
  then
    clear
    _print_banner "You have a non-empty \"trunk\" folder, but there are also" \
    "files/folders in the root of your repository. There is"\
    "no way to intelligently know what to do with these, and"\
    "this is a discouraged practice. As such, the root of the"\
    "repository will be treated as \"trunk\", and there will"\
    "be a \"trunk\" folder next to the rest of the files."\
    "If this is not the desired outcome, please take a few"\
    "minutes to consolidate the files into \"trunk\" and then"\
    "re-run the migration script".
    echo ""
    read -n 1 -s -r -p "Press any key to continue, CTRL+C to exit..."
    echo ""
    FLAGS+=" --trunk=/"
  elif [[ ! -z ${TRUNK} ]] && [[ ! -z $(svn ls ${REPO_URL}/trunk ${SVN_OPTIONS}) ]]
  then
    [[ -z ${ROOT_FILES} ]] && FLAGS+=" --trunk=trunk"
  fi
}

function _process_submodules()
{
  echo '' > /tmp/github_remotes.txt
  for SUBMODULE in ${SUBMODULES}
  do
    (
      REPO_URL=${REPOSITORY}/${SUBMODULE}
      REPO_NAME=$(echo ${SUBMODULE}|awk -F'/' {'print $(NF-1)'})
      GITHUB_REMOTE=${GITHUB_URL}/${GITHUB_ORG}/${REPO_NAME}.git
      REV_LIST=$(svn log ${REPO_URL} ${SVN_OPTIONS}|grep ^r[0-9]|awk {'print $1'}|sed 's/r//'|sort)
      echo "${SUBMODULE},${GITHUB_REMOTE}" >> /tmp/github_remotes.txt
      _get_svn_layout
      _prepare_github
      _git_svn_clone
      cd ${REPO_NAME}
      _migrate_trunk
      _migrate_branches
      _migrate_tags
      cd ..
    )
  done
}

function _git_svn_clone_without_history()
{
  _print_banner "Cloning ${REPO_NAME} without history"
  _get_svn_layout
  git svn clone -rHEAD ${REPO_URL} ${REPO_NAME} ${FLAGS} --prefix=svn/
}

function _git_svn_clone_with_history()
{
  _print_banner "Cloning ${REPO_NAME} without history"
  _get_svn_layout
  git svn clone ${REPO_URL} ${REPO_NAME} ${FLAGS} --prefix=svn/
}

function _git_svn_clone()
{
  git svn init ${REPO_URL} ${REPO_NAME} ${FLAGS} --prefix=svn/
  (
    cd ${REPO_NAME}
    #REV=0
    REV_LIST=$(svn log ${REPO_URL} ${SVN_OPTIONS}|grep ^r[0-9]|awk {'print $1'}|sed 's/r//'|sort -g)
    REV_COUNT=$(echo ${REV_LIST}|wc -w)
    REV_HEAD=$(echo ${REV_LIST}|awk {'print $NF'})
    ## Setup the progress bar
    OLD_REV=0
    # Start Script
    for REV in ${REV_LIST}
    do
      clear
      HIDECURSOR
      echo -e "" && echo -e ""
      DRAW
      echo -e "             CLONING ${REPO_NAME^^}: REV ${REV}"
      echo -e "    lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk"
      echo -e "    x                                                   x"
      echo -e "    mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj"
      WRITE
      ## Fill in the gaps of the progress bar
      if [[ $((${REV} - ${OLD_REV} )) -gt 1 ]]
      then
        while [[ ${OLD_REV} -lt ${REV} ]]
        do
          showBar ${OLD_REV} ${REV_HEAD}
          ((OLD_REV++))
        done
      fi
      showBar ${REV} ${REV_HEAD}
      git svn fetch -qr${REV} ${AUTHORS} &>> ${LOG_FILE} > /dev/null
      RESULT=$?
      while [[ ${RESULT} -ne 0 ]]
      do
        echo "" && echo "" && echo "" && echo "" && echo ""
        echo "Revision ${REV} failed to clone, possibly due to corruption."
        read -p "Would you like to attempt revision ${REV} again? (yes/no) " RETRY
        while [[ "${RETRY,,}" != "yes" ]] && [[ "${RETRY,,}" != "no" ]]
        do
          echo 'Please type "yes" or "no"'
          read -p "Would you like to attempt revision ${REV} again? (yes/no) " RETRY
        done
        if [[ "${RETRY,,}" == "no" ]]
        then
          RESULT=0
        else
          clear
          echo "Retrying revision ${REV}..."
          HIDECURSOR
          echo -e "" && echo -e ""
          DRAW
          echo -e "             CLONING ${REPO_NAME^^}: REV ${REV}"
          echo -e "    lqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqk"
          echo -e "    x                                                   x"
          echo -e "    mqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqj"
          WRITE
          showBar ${REV} ${REV_HEAD}
          git svn fetch -qr${REV} ${AUTHORS} &>> ${LOG_FILE} > /dev/null
          RESULT=$?
        fi
      done
      OLD_REV=${REV}
    done
    PUT 10 12
    echo -e ""
    NORM
  )
}

function _initialize_lfs()
{
  LARGE_FILES=$(find . -path ./.git -prune -o -size +10M -exec ls {} \+)
  if [[ ${#LARGE_FILES} -ge 1 ]]
  then
    _print_banner "Initializing Git-LFS"
    git lfs install
    for FILE in ${LARGE_FILES}
    do
      EXTENSION=$(echo ${FILE}|awk -F'.' {'print " *."$3'})
      git lfs track ${EXTENSION}
      git add ${EXTENSION}
    done
    git add .gitattributes
    git commit -m "Initialized Git-LFS"
  fi
}

function _add_git_submodules()
{
  (
   REPO_NAME=$(svn info ${REPOSITORY} ${SVN_OPTIONS}|grep '^Path'|awk {'print $2'}|sed 's/ /-/g')
   [[ $(pwd|awk -F'/' {'print $NF'}) != ${REPO_NAME} ]] && cd ${REPO_NAME}
   for SUBMODULE in $(cat /tmp/github_remotes.txt)
   do
     GITHUB_REMOTE=$(echo ${SUBMODULE}|awk -F',' {'print $2'})
     LOCAL_PATH=$(echo ${SUBMODULE}|awk -F',' {'print $1'})
     rm -fr ${LOCAL_PATH} &>> ${LOG_FILE}
     git add -u
     git submodule add ${GITHUB_REMOTE} ${LOCAL_PATH} &>> ${LOG_FILE}
     #git submodule init
     git add .gitmodules ${LOCAL_PATH} && git add -u
     git commit -m"Added git submodule ${SUBMODULE}" &>> ${LOG_FILE}
   done
   git push &>> ${LOG_FILE}
  )
}

PUT(){ echo -en "\033[${1};${2}H";}
DRAW(){ echo -en "\033%";echo -en "\033(0";}
WRITE(){ echo -en "\033(B";}
HIDECURSOR(){ echo -en "\033[?25l";}
NORM(){ echo -en "\033[?12l\033[?25h";}
function showBar()
{
  percDone=$(echo 'scale=2;'$1/$2*100 | bc)
  halfDone=$(echo $percDone/2 | bc) #I prefer a half sized bar graph
  barLen=$(echo ${percDone%'.00'})
  halfDone=$(expr $halfDone + 6)
  tput bold
  PUT 7 28; printf "%4.4s  " $barLen%     #Print the percentage
  PUT 5 $halfDone;  echo -e "\033[7m \033[0m" #Draw the bar
  tput sgr0
}

function _cleanup()
{
  rm -f /tmp/{submodules,github_remotes}.txt
  rm -f ~/.netrc
}
