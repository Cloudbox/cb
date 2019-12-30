#!/bin/bash
#########################################################################
# Title:         Cloudbox Script                                        #
# Author(s):     desimaniac, chazlarson                                 #
# URL:           https://github.com/cloudbox/cb                         #
# --                                                                    #
#         Part of the Cloudbox project: https://cloudbox.works          #
#########################################################################
#                   GNU General Public License v3.0                     #
#########################################################################

# Restart script in SUDO
# https://unix.stackexchange.com/a/28793
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

CLOUDBOX_PATH="/srv/git/cloudbox"
CLOUDBOX_REPO="https://github.com/Cloudbox/Cloudbox.git"

function ansible_playbook_command() {
  arg=("$@")
  env ANSIBLE_CONFIG=\'"${CLOUDBOX_PATH}"/ansible.cfg\' \
    '/usr/local/bin/ansible-playbook' \
    "${CLOUDBOX_PATH}/cloudbox.yml" \
    --become \
    -vv \
    ${arg}
}

role=""  # Default to empty package
target=""  # Default to empty target

while getopts ":h" opt; do
  case ${opt} in
    h )
      echo "Usage:"
      echo -e "    cb -h                  Display this help message"
      echo -e "    cb install <package>   Install <package>"
      echo -e "    cb remove <package>    Remove <package> \e[38;5;5m[DATA LOSS WILL OCCUR]\e[0m."
      echo -e "    cb update              Update local cloudbox files"
      echo -e "    cb tags                Show valid task tags"
      echo -e "    cb backup              Start a manual backup"
      echo -e "    cb ncdu                opens ncdu at / with /opt/plex excluded"
      echo -e "    cb ncdu all            opens ncdu at /"
      echo -e "    cb bench               Run nench benchmark"
      echo -e "    cb upgrade             Run cloudbox tag to upgrade"
      echo -e "    cb upgrade os          Run apt-get update/upgrade/clean"
      echo -e "    cb usage local         Space used by /mnt/local directory"
      echo -e "    cb usage sync          Space used by Plex sync directory"
      echo -e "    cb certs status        Display certs status."
      echo -e "    cb certs renew         Force-renew all certs."
      echo -e "    cb plex token          Retrieve plex token"
      echo -e "    cb plex fix-trash      Fix plex trash"
      echo -e "    cb chkcfg <package>    Smoke test on config for <package>"
      echo -e "    cb logs  <package>     Display logs for <package>."

      exit 0
      ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
  esac
done
shift $((OPTIND -1))

install-tag () {
  if list-tags | grep -q "$1"; then
    ansible_playbook_command "--skip-tags settings --tags ${1}"
  else
    echo "invalid tag: " $1
  fi
}

remove-tag () {
  if list-tags | grep -q "$1"; then
  	echo -e "About to \e[38;5;5mIRREVOCABLY DELETE\e[0m /opt/${1}"
    read -p "Do you wish to proceed?" yn
    case $yn in
        [Yy]* ) 
            docker rm -f ${1}
            rm -fr /opt/${1}
            ;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
  else
    echo "invalid tag: " $1
  fi
}

list-tags () {
  ansible_playbook_command "--list-tags"
}



subcommand=$1; shift  # Remove 'cb' from the argument list
case "$subcommand" in

  # Parse options to the various sub commands

  update)
    echo "Updating Cloudbox..."
    ./cb_repo.sh
    ansible_playbook_command "--tags settings"
    ;;

  upgrade)
    area=$1; shift
    case "$area" in
	  os)
		echo -e "\e[96mUpdating OS \e[39m"
		sudo apt-get update
		sudo apt-get dist-upgrade -y
		sudo apt-get autoremove -y
		sudo apt-get autoclean -y
		;;
	  '' )
        echo "upgrading Cloudbox"
		;;
	  * )
        echo "Don't know how to upgrade" $area
		;;
	esac
    ;;
    
  install)
    role=${1}
    install-tag ${role}
    ;;

  remove)
    role=${1}
    remove-tag ${role}
    ;;

  tags)
    ansible_playbook_command "--list-tags"
    ;;

  backup)
    ansible_playbook_command "--tags ${subcommand}"
    ;;

  ncdu)
    area=$1; shift
    case "$area" in
	  all)
		echo -e "\e[96mLaunching NCDU (excluding Plex). \e[39m"
		echo
		ncdu -x / --exclude=/opt/plex
		;;
	  * )
		echo -e "\e[96mLaunching NCDU (including Plex). \e[39m"
		echo
		ncdu -x /
		;;
	esac
    ;;

  bench)
	echo -e "\e[96mLaunching Nench Benchmark. \e[39m"
	echo
	curl -s wget.racing/nench.sh | bash
    ;;
    
  usage)
    area=$1; shift
    case "$area" in
	  sync)
		currSize=$(sudo du -sh '/opt/plex/Library/Application Support/Plex Media Server/Cache/Transcode' | awk '{print $1}')
		echo -e "\e[96mSync Folder Size is: $currSize \e[39m"
		;;
	  local)
		currSize=$(sudo du -sh '/mnt/local' | awk '{print $1}')
		echo -e "\e[96mLocal Data Size is: $currSize \e[39m"
		;;
	  * )
		echo "INVALID usage parameter:" $area
		echo "Valid parameters are:"
		echo "  sync"
		echo "  local"
		;;
	esac
    ;;

  certs)
    cmd=$1; shift
    case "$cmd" in
	  renew)
		echo -e "\e[96mForcing Renew of all Necessary Cerificates. \e[39m"
		docker exec letsencrypt /app/signal_le_service
		;;
	  status)
		echo -e "\e[96mLaunching Certificate Information. \e[39m"
		docker exec letsencrypt /app/cert_status
		;;
	  * )
		echo "INVALID usage parameter"
		;;
	esac
    ;;
    
  plex)
    cmd=$1; shift
    case "$cmd" in
	  token)
		echo -e "\e[96mLaunching Plex Token Script. \e[39m"
		/opt/scripts/plex/plex_token.sh
		;;
	  "fix-trash" )
		echo -e "\e[96mRunning Plex Trash Fixer Script. \e[39m"
		/opt/scripts/plex/plex_trash_fixer.py
		;;
	  * )
        echo "INVALID:" $cmd
		;;
	esac
    ;;

  chkcfg)
    area=$1; shift
	echo -e "\e[96mThis validates JSON FORMAT only\e[39m"
    case "$area" in
	  cloudplow)
		echo -e "\e[96mValidating cloudplow config.json\e[39m"
		echo
		cat /opt/cloudplow/config.json | jq empty
		echo -e "\e[96mAny errors are listed above\e[39m"
		;;
	  traktarr)
		echo -e "\e[96mValidating traktarr config.json\e[39m"
		echo
		cat /opt/traktarr/config.json | jq empty
		echo -e "\e[96mAny errors are listed above\e[39m"
		;;
	  plex_dupefinder)
		echo -e "\e[96mValidating plex_dupefinder config.json\e[39m"
		echo
		cat /opt/plex_dupefinder/config.json | jq empty
		echo -e "\e[96mAny errors are listed above\e[39m"
		;;
	  * )
		echo "INVALID chkcfg parameter:" $area
		echo "Valid parameters are:"
		echo "  cloudplow"
		echo "  traktarr"
		echo "  plex_dupefinder"
		;;
	esac
    ;;

  logs)
    package=$1; shift
    case "$package" in
	  autoscan)
		echo -e "\e[96mLaunching Plex Autoscan Log Tail. \e[39m"
		echo
		tail -f /opt/plex_autoscan/plex_autoscan.log -n 30
		;;
	  cloudplow)
		echo -e "\e[96mLaunching Cloudplow Log Tail. \e[39m"
		echo
		tail -f /opt/cloudplow/cloudplow.log -n 30
		;;
	  * )
		echo "INVALID log parameter:" $area
		echo "Valid parameters are:"
		echo "  autoscan"
		echo "  cloudplow"
		;;
	esac
    ;;
    
  *)
    echo "cb: missing or incorrect parameter
Try 'cb -h' for more information."
    ;;
esac
