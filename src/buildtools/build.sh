#!/bin/bash
version="$1"

if [ -z "$version" ]; then
	version="devbuild"
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

shfmt ./backup/docker-backup.sh > ./backup/docker-backup.new
mv ./backup/docker-backup.new ./backup/docker-backup.sh
shfmt ./backup/docker-backup-cron.sh > ./backup/docker-backup-cron.new
mv ./backup/docker-backup-cron.new ./backup/docker-backup-cron.sh
shfmt ./entrypoint.sh > ./entrypoint.new
mv ./entrypoint.new ./entrypoint.sh

shfmt ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt ./entrypoint.sh > ./build/entrypoint.sh

docker buildx create --name multiarchbuilder --use --bootstrap
docker buildx build . --load --platform linux/arm64 -t "crockerish/docker-backup:$version" | less -r


