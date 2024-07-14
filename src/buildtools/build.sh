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

shfmt ./backup/docker-backup.sh > ./build/docker-backup.sh
shfmt ./backup/docker-backup-cron.sh > ./build/docker-backup-cron.sh
shfmt ./entrypoint.sh > ./build/entrypoint.sh

docker buildx build . \
	-t "crockerish/docker-backup:$version"
