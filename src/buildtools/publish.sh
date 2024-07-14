#!/bin/bash
version="$1"

if [ -z "$version" ]; then
	version="dev"
fi

cd $HOME/src/docker-backup/src

shellcheck ./backup/docker-backup.sh

if [[ "$?" -eq 0 ]]; then
        echo "Shellcheck successful."
else
        exit
fi

shellcheck ./backup/docker-backup-cron.sh

if [[ "$?" -eq 0 ]]; then
        echo "Shellcheck successful."
else
        exit
fi

shellcheck ./entrypoint.sh

if [[ "$?" -eq 0 ]]; then
        echo "Shellcheck successful."
else
        exit
fi

shfmt -mn -s ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt -mn -s ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt -mn -s ./entrypoint.sh > ./build/entrypoint.sh

docker buildx create --name multiarchbuilder --use --bootstrap

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
