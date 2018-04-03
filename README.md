# svn2github-bash

This script migrates a subversion repository to GitHub, with some logic for dealing with nested repositories.

## Features
- Sizing of the remote repository
- Detection of nested folders with `trunk`, `tags` and `branches`
- Selectable subfolders for separate conversion
- Progress bar
- Failed `fetch` retries

## Usage
```bash
chmod +x svn2github.sh
./svn2github.sh
```

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

