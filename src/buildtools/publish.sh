#!/bin/bash
version="$1"

if [ -z "$version" ]; then
	version="dev"
fi

cd $HOME/src/docker-backup/src
versiontag=$(cat ./version.tag)

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

shfmt ./backup/docker-backup.sh > ./backup/docker-backup.new
mv ./backup/docker-backup.new ./backup/docker-backup.sh
shfmt ./backup/docker-backup-cron.sh > ./backup/docker-backup-cron.new
mv ./backup/docker-backup-cron.new ./backup/docker-backup-cron.sh
shfmt ./entrypoint.sh > ./entrypoint.new
mv ./entrypoint.new ./entrypoint.sh

shfmt -mn -s ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt -mn -s ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt -mn -s ./entrypoint.sh > ./build/entrypoint.sh

docker buildx create --name multiarchbuilder --use --bootstrap

if [ "$version" = "latest" ]; then
	docker buildx build --push . \
        	--platform linux/amd64,linux/arm64 \
		-t "crockerish/docker-backup:dev" \
          	-t "crockerish/docker-backup:$version" \
		-t "crockerish/docker-backup:$versiontag"
	else
	docker buildx build --push . \
        	--platform linux/amd64,linux/arm64 \
        	-t "crockerish/docker-backup:$version"
fi

