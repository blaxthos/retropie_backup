#!/bin/bash

### RetroPie Save Game Backup Script v0.5 (blaxthos)
### 
### This script will incrementally back up all saved game slots
### that have been modified since the last time it was run

### Configuration

## QUIET - mute script output (-q|-v)
QUIET=1

## FULLBACKUP - always perform a full backup (-a)
FULLBACKUP=0      

## BACKUPSDIR - where to put backup tarballs (-b <dir>)
BACKUPSDIR="/home/pi/RetroPie-Backups"  

## GAMESDIR - where to find savegame files (-g <dir>)
GAMESDIR="/home/pi/RetroPie"  

### End Configuration (do not edit below this line)

## Operational Variables 
MYTIME=$(date +"%Y%m%d%H%M%S")
RUNFILE="/tmp/rp_backup.$MYTIME"
MYNAME="savegames-${MYTIME}.tgz"
MYBACKUP="${BACKUPSDIR}/${MYNAME}"
MYFILES="/tmp/rp_backup.$MYTIME.files"
NEWER=""
ORIGIN=$PWD
SAVEIFS=$IFS

## Functions

usage(){
  printf "\nUsage: $0 [-q|-v] [-a] [-b <backupdir>] [-g <gamesdir>]\n\n" 1>&2; exit 1;
}

abort(){
  QUIET=0
  local code=$1
  shift
  output "ABORT $code - $*"
  [ -a $RUNFILE ] && rm -rf $RUNFILE
  [ -a $MYFILES ] && rm -rf $MYFILES
  cd $ORIGIN
  IFS=$SAVEIFS
  exit $code
}

happy_ending(){
  output "Cleaning up"
  rm -rf $RUNFILE
  rm -rf $MYFILES
  cd $ORIGIN
  IFS=$SAVEIFS
  exit 0
}

init_dirs(){
  MYBACKUP="${BACKUPSDIR}/${MYNAME}"
  if [ ! -d $BACKUPSDIR ]; then
    output "Creating $BACKUPSDIR"
    mkdir $BACKUPSDIR || abort 253 "Unable to create $BACKUPSDIR"
  else
    get_lastbackup
  fi
  touch $BACKUPSDIR/.lastrun
}

output(){
  if [ $QUIET -eq 0 ]; then
    echo "$(date) - $*"
  fi
}

get_lastbackup(){
  [ $FULLBACKUP -eq 1 ] && return
  [ $(ls $BACKUPSDIR|grep tgz|wc -l) -eq 0 ] && output "No previous backups detected" && return
  local newestfile=$(ls -t $BACKUPSDIR|grep tgz|head -n 1)
  output "Found most recent backup $newestfile"
  output "Only saving files newer than $(stat -c %y ${BACKUPSDIR}/$newestfile)"
  NEWER="-newer ${BACKUPSDIR}/$newestfile"
}

get_savefiles(){
  output "Searching $GAMESDIR for save files"
  cd $GAMESDIR
  nice find . -regex '.*\(srm\|state\|state\([0-9]\|[1-9][0-9]\)\)$' $NEWER > $MYFILES || abort 252 "Unable to write to 
$MYFILES"
  [ -a $MYFILES ] && output "Found $(cat $MYFILES|wc -l) savefiles to process"
}

tar_savefiles(){
  [ $(cat $MYFILES|wc -l) -lt 1 ] && return
  output "Creating backup $MYBACKUP"
  cd $GAMESDIR
  nice tar -c -z -T $MYFILES -f $MYBACKUP || abort 251 "FAILED COMMAND: tar -c -z -T $MYFILES -f $MYBACKUP"
  output "Backup file size is $(stat --printf="%s" $MYBACKUP) bytes"
  create_digest
}

create_digest(){
  output "Updating digest"
  local digest=${BACKUPSDIR}/.digest
  IFS=$(echo -en "\n\b")
  for file in $(cat $MYFILES); do
    printf "%s,%s\n" "$MYNAME" "$file" >> $digest
  done
  IFS=$SAVEIFS
}

## init
[ -z "$PS1" ] && QUIET=0
  
## Parse some args
while getopts ":qvab:g:h" o; do
  case "${o}" in
    q)
      QUIET=1; ;;
    b)
      BACKUPSDIR=${OPTARG} && output "(-b) Overriding backups directory to $BACKUPSDIR"; ;;
    g)
      GAMESDIR=${OPTARG} && output "(-g) Overriding games directory to $GAMESDIR"; ;;
    a)
      FULLBACKUP=1 && output "(-a) Forcing a full backup"; ;;
    v)
      QUIET=0; ;;
    h)
      usage; ;;
  esac
done
shift $((OPTIND-1))
output "Initializing"

[ -a $RUNFILE ] && abort 255 "Already running?!"
touch $RUNFILE || abort 254 "Unable to write to /tmp"

init_dirs
get_savefiles
tar_savefiles

## Happy Ending
happy_ending
