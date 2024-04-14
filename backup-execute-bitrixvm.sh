#!/bin/bash -l
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $CURRENT_DIR/config.ini

### Variables ###

# Set script start time
START_TIME=`date +%s`

# Exclude is a temp file that stores dirs that we dont want to backup
EXCLUDE=$CURRENT_DIR/exclude

# Set backup archive name to current day
ARCHIVE=$(date +'%F--%H-%M')

### Start processing ###

# Dump databases to corresponding user dirs
$CURRENT_DIR/dump-databases-bitrixvm.sh



COUNT=0

USER="bitrix"
USER_DIR="/home/$USER"

    echo "$(date +'%F %T') ########## Processing user $USER ##########"
    echo

    # Clean exclusion list
    if [ -f "$EXCLUDE" ]; then
      rm $EXCLUDE
    fi

    # Build exclusion list
    # No need for drush backups, tmp folder and .cache dir
    echo "$USER_DIR/drush-backups" >> $EXCLUDE
    echo "$USER_DIR/backups" >> $EXCLUDE
    echo "$USER_DIR/tmp" >> $EXCLUDE
    echo "$USER_DIR/.cache" >> $EXCLUDE


    WEB_DIR="$USER_DIR/www"
    if [ -d "$WEB_DIR/bitrix/cache" ]; then
      echo "$WEB_DIR/bitrix/cache/*" >> $EXCLUDE
      echo "$WEB_DIR/bitrix/managed_cache/*" >> $EXCLUDE
      echo "$WEB_DIR/bitrix/html_pages/*/*" >> $EXCLUDE
      echo "$WEB_DIR/bitrix/backup/*" >> $EXCLUDE
      echo "$WEB_DIR/upload/resize_cache/*" >> $EXCLUDE
    fi
    for WEB_DIR in $USER_DIR/ext_www/*; do
        if [ -d "$WEB_DIR/bitrix/cache" ]; then
          echo "$WEB_DIR/bitrix/cache/*" >> $EXCLUDE
          echo "$WEB_DIR/bitrix/managed_cache/*" >> $EXCLUDE
          echo "$WEB_DIR/bitrix/html_pages/*/*" >> $EXCLUDE
          echo "$WEB_DIR/bitrix/backup/*" >> $EXCLUDE
          echo "$WEB_DIR/upload/resize_cache/*" >> $EXCLUDE
        fi
    done
    

    # Set user borg repo path
    USER_REPO=$REPO_USERS_DIR/$USER
    
    # copy crontabs in userdir
    if [ -e "/var/spool/cron/$USER" ]; then
      mkdir -p /home/$USER/conf-backups/var/spool/
      cp -af /var/spool/cron /home/$USER/conf-backups/var/spool/
    fi

    # Check if repo was initialized, if its not we perform borg init
#     if ! [ -d "$USER_REPO/data" ]; then
#       echo "-- No repo found. Initializing new borg repository $USER_REPO"
#       mkdir -p $USER_REPO
      borg init $OPTIONS_INIT $USER_REPO
#     fi

    echo "-- Creating new backup archive $USER_REPO::$ARCHIVE"
    borg create $OPTIONS_CREATE $USER_REPO::$ARCHIVE $USER_DIR --exclude-from=$EXCLUDE
    echo "-- Cleaning old backup archives"
    borg prune $OPTIONS_PRUNE $USER_REPO
    borg compact $USER_REPO

    let COUNT++
    echo



echo "$(date +'%F %T') ########## $COUNT USERS PROCESSED ##########"

# We dont need exclude list anymore
if [ -f "$EXCLUDE" ]; then
  rm $EXCLUDE
fi

echo
echo
echo "$(date +'%F %T') #################### SERVER LEVEL BACKUPS #####################"

echo "$(date +'%F %T') ########## Executing server config backup: $ETC_DIR ##########"
# if ! [ -d "$REPO_ETC/data" ]; then
#   echo "-- No repo found. Initializing new borg repository $REPO_ETC"
#   mkdir -p $REPO_ETC
  borg init $OPTIONS_INIT $REPO_ETC
# fi
echo "-- Creating new backup archive $REPO_ETC::$ARCHIVE"
borg create $OPTIONS_CREATE $REPO_ETC::$ARCHIVE $ETC_DIR
echo "-- Cleaning old backup archives"
borg prune $OPTIONS_PRUNE $REPO_ETC
borg compact $REPO_ETC
echo

# if [[ ! -z "$REMOTE_BACKUP_SERVER" && ! -z "$REMOTE_BACKUP_SERVER_DIR" ]]; then
#   echo
#   echo "$(date +'%F %T') #################### SYNC BACKUP DIR $BACKUP_DIR TO REMOTE SERVER: $REMOTE_BACKUP_SERVER:$REMOTE_BACKUP_SERVER_DIR ####################"
#   rsync -za --delete --stats $BACKUP_DIR/ $REMOTE_BACKUP_SERVER_USER@$REMOTE_BACKUP_SERVER:$REMOTE_BACKUP_SERVER_DIR/
# fi

echo
echo "$(date +'%F %T') #################### BACKUP COMPLETED ####################"

END_TIME=`date +%s`
RUN_TIME=$((END_TIME-START_TIME))

echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
echo
