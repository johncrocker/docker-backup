#!/bin/bash
version="$1"
 
if [ -z "$version" ]; then
	version="dev"
fi

cd $HOME/src/docker-backup/src

shfmt ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt ./entrypoint.sh > ./build/entrypoint.sh

docker buildx build . \
	-t "crockerish/docker-backup:$version"

docker run -it --rm --name docker-backup-test \
	--env-file ./backup/docker-backup-container.env \
	-e TZ=Europe/London \
	-e DOCKER_BACKUP_CONTAINERS=mongo-db \
	-e BACKUP_RUN_ONCE=false \
	-v /var/run/docker.sock:/var/run/docker.sock:ro \
	-v /:/source:ro \
	-v /media/external/docker-backup:/target \
	-v $HOME/tmp/logs:/logs \
	-v $HOME/tmp/cron:/etc/cron.schedule \
	"crockerish/docker-backup:$version"
