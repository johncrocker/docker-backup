#!/bin/bash

HOUR=$(date +%H)

if [[ "$HOUR" = "01" ]]; then
	BACKUPDATE="$(date '+%Y%m%d-%H%M')"
	LOGFILENAME="/logs/docker-backup-""$BACKUPDATE"".log"

	if [ ! -f "$LOGFILENAME" ]; then
                echo "" >"$LOGFILENAME"
        fi

	cd /app

	./docker-backup.sh  2>&1 | tee "$LOGFILENAME"
fi

