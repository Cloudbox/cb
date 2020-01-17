#!/bin/bash
#########################################################################
# Title:         Cloudbox Repo Cloner Script                            #
# Author(s):     desimaniac                                             #
# URL:           https://github.com/cloudbox/cb                         #
# --                                                                    #
#         Part of the Cloudbox project: https://cloudbox.works          #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

## Variables
VERBOSE=false
CLOUDBOX_PATH="/srv/git/cloudbox"
CLOUDBOX_REPO="https://github.com/cloudbox/cloudbox.git"

while getopts 'v' f; do
	case $f in
	v)	VERBOSE=true;;
	esac
done

$VERBOSE || exec &>/dev/null

## Clone Cloudbox and pull latest commit
if [ -d "$CLOUDBOX_PATH" ]; then
    if [ -d "$CLOUDBOX_PATH/.git" ]; then
        cd "$CLOUDBOX_PATH"
        git fetch --all --prune
        git checkout develop
        git reset --hard origin/develop
        git submodule update --init --recursive
    else
        cd "$CLOUDBOX_PATH"
        rm -rf library/
        git init
        git remote add origin "$CLOUDBOX_REPO"
        git fetch --all --prune
        git branch master origin/develop
        git reset --hard origin/develop
        git submodule update --init --recursive
    fi
else
    git clone "$CLOUDBOX_REPO" "$CLOUDBOX_PATH"
    cd "$CLOUDBOX_PATH"
    git submodule update --init --recursive
fi

## Copy settings and config files into Cloudbox folder
shopt -s nullglob
for i in "$CLOUDBOX_PATH"/defaults/*.default; do
    if [ ! -f "$CLOUDBOX_PATH/$(basename "${i%.*}")" ]; then
        cp -n "${i}" "$CLOUDBOX_PATH/$(basename "${i%.*}")"
    fi
done
shopt -u nullglob
