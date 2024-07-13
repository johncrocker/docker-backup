#!/bin/bash
version="$1"

if [ -z "$version" ]; then
	version="dev"
fi

cd $HOME/src/docker-backup/src

docker buildx create --name multiarchbuilder --use --bootstrap

shfmt -mn -s ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt -mn -s ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt -mn -s ./entrypoint.sh > ./build/entrypoint.sh

if [ "$version" = "latest" ]; then
	docker buildx build --push . \
        	--platform linux/amd64,linux/arm64 \
		-t "crockerish/docker-backup:dev" \
          	-t "crockerish/docker-backup:$version"
else
	docker buildx build --push . \
        	--platform linux/amd64,linux/arm64 \
        	-t "crockerish/docker-backup:$version"
fi

docker buildx rm multiarchbuilder
