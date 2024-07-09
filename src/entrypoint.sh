#!/bin/sh

export DOCKER_BACKUP_COMTAINERIDD=""
export INSIDE_CONTAINER=""

if [ -f /.dockerenv ]; then
	containerid=$(cat /etc/hostname)
	export INSIDE_CONTAINER="true"
	export DOCKER_BACKUP_CONTAINERID=$(docker inspect "$containerid" -f "{{.Id}}")
	export BACKUP_SOURCE="/source"
fi

cd /app
./docker-backup.sh "$DOCKER_BACKUP_CONTAINERS"
