# svn2github-bash

This script migrates a subversion repository to GitHub, with some logic for dealing with nested repositories.

## Requirements
This script was developed using `CentOS 7` with the following packages installed:
- [ ] `bc`
- [ ] `git2u`
- [ ] `git2u-svn`
- [ ] `Git-LFS`

To install, run the following commands:
```bash
sudo yum -y localinstall https://centos7.iuscommunity.org/ius-release.rpm
sudo yum -y install git2u-svn git2u bc git-lfs
```
### Building the Docker container
```bash
docker build -t github/svn2github .
```

## Features
- Sizing of the remote repository
- Detection of nested folders with `trunk`, `tags` and `branches`
- Selectable subfolders for conversion to _git submodules_
- Progress bar
- Failed `fetch` retries
- Large file detection, with automatic LFS initialization

## Usage
```bash
chmod +x svn2github.sh
./svn2github.sh
```

### Running in Docker
1. Run the container
```bash
docker run -dit --name svn2github github/svn2github
```
2. Enter a shell prompt in the container
```bash
docker exec -it svn2github bash
```
3. Edit the `settings.ini` file
4. Execute the script
```bash
./svn2github.sh
```

### Running in Windows (Git-Bash)
1. Download the release and extract it
2. Ensure you have a Subversion client installed _with the CLI utilities_.
3. Open the `Git Bash` terminal
4. Add the Subversion binaries to your path
    - `export PATH=${PATH}:/c/Program\ Files/TortoiseSVN/bin`
5. Edit the `settings.ini` file and add your specifics
6. Add your `git config` properties
    - `git config --global user.name "Kal El"`
    - `git config --global user.email "manofsteel@krypton.org"`
7. Execute the `svn2github.sh` script and follow the prompts
    - `./svn2github.sh`

## Using individual functions
### _svn_sizer
```bash
$ source settings.ini
$ source _functions.sh
$ _svn_sizer
###################################
##                               ##
##  Discovering repository size  ##
##                               ##
###################################

Total Size: 545.575 MB
Number of Files: 17.276 K
```

## Testing
This script was successfully tested with the following repositories:

| URL | Name | Has Submodules | Has Branches | Has Tags |
| :--- | :---: | :---: | :---: | :---: |
| https://svn.eionet.europa.eu/repositories/NatureWatch | `NatureWatch` | _Yes_ | _Only in submodules_ | _Yes_ |
| https://svn.code.sf.net/p/ultrastardx/svn | `ultrastardx` | _No_ | _Yes_ | _Yes_ |

#### Sample `settings.ini`
```bash
REPOSITORY=https://svn.eionet.europa.eu/repositories/NatureWatch
GITHUB_TOKEN=faf0bc75ea0740ef240g2cce40a488aa98229ef3
GITHUB_URL=https://ghe-test.github.local
GITHUB_ORG=GitHub-Demo
AUTHORS_FILE=/tmp/authors.txt
SVN_USERNAME=anonymous
SVN_PASSWORD=anonymous
ENABLE_SUBMODULES=true
MIGRATE_HISTORY=true
```

## Caveats

1. You may encounter issues with unsigned or self-signed certificates. In this case, disable `http.sslVerify` before running the script: `git config --global http.sslVerify false`

**Remember to remove this when you're done!!**

2. You may encounter issues with cloning the history if your repository has corrupt revisions. In this case, it will be required to do a clean cutover. This script does not yet fully support a clean cutover, but it is in the works

3. If you have a `trunk` folder _and_ files in the root of the repository, the script will treat the root as trunk. This is because `git-svn` cannot treat 2 folders like `master`. If this is not the desired behavior then it is up to the administrator to consolidate these files either in `trunk` or in the root. If no consolidation is done, you will still have all of those files, and a trunk folder in your `master` branch after the migration

4. `Git-LFS` is automatically initialized if large files are discovered, but this does not get around the max filesize limit of GitHub. You will still need to either increase that filesize temporarily for the migration, or else manually clean up the files. This is not handled by the script
