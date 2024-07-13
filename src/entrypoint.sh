#!/bin/sh

export DOCKER_BACKUP_COMTAINERID=""
export INSIDE_CONTAINER=""

if [ -f /.dockerenv ]; then
	containerid=$(cat /etc/hostname)
	export INSIDE_CONTAINER="true"
	export DOCKER_BACKUP_CONTAINERID=$(docker inspect "$containerid" -f "{{.Id}}")
	export BACKUP_SOURCE="/source"
fi

BACKUPDATE="$(date '+%Y%m%d-%H%M')"
LOGFILENAME="/logs/docker-backup-""$BACKUPDATE"".log"

mkdir -p /etc/cron.schedule/cron.hourly
mkdir -p /etc/cron.schedule/cron.daily
mkdir -p /etc/cron.schedule/cron.weekly
mkdir -p /etc/cron.schedule/cron.monthly

if [ ! -f /cron.schedule/crontab ]; then
	cp /etc/crontab.default /etc/cron.schedule/crontab
fi

cd /app

if [ "$BACKUP_RUN_ONCE" = "true" ]; then
	if [ ! -f "$LOGFILENAME" ]; then
		echo "" >"$LOGFILENAME"
	fi

	echo "Starting run-once then shutdown"
	./docker-backup.sh "$DOCKER_BACKUP_CONTAINERS" 2>&1 | tee "$LOGFILENAME"
else
	if [ -f /etc/cron.schedule/crontab ]; then
		echo "Loading crontab settings"
		crontab /etc/cron.schedule/crontab
	fi

	echo "Starting scheduler"
	/usr/sbin/crond -f -d 6
fi
