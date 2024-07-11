#!/bin/sh

export DOCKER_BACKUP_COMTAINERIDD=""
export INSIDE_CONTAINER=""

if [ -f /.dockerenv ]; then
	containerid=$(cat /etc/hostname)
	export INSIDE_CONTAINER="true"
	export DOCKER_BACKUP_CONTAINERID=$(docker inspect "$containerid" -f "{{.Id}}")
	export BACKUP_SOURCE="/source"
fi

LOGFILENAME="/logs/docker-backup-""$BACKUPDATE"".log"

if [ ! -f "$LOGFILENAME" ]; then
	echo "" >"$LOGFILENAME"
fi

cd /app
./docker-backup.sh "$DOCKER_BACKUP_CONTAINERS" 2>&1 | tee "$LOGFILENAME"
