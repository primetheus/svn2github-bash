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
