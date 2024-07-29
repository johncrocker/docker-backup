#!/bin/sh
BACKUPDATE="$(date '+%Y%m%d-%H%M')"
LOGFILENAME="/logs/docker-backup-""$BACKUPDATE"".log"
if [ ! -f "$LOGFILENAME" ];then
echo "" >"$LOGFILENAME"
fi
cd /app||exit
./docker-backup.sh >&1|tee "$LOGFILENAME"
