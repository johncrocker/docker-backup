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

shfmt ./backup/docker-backup.sh > ./backup/docker-backup.new

        if [[ "$?" -eq 0 ]]; then
                mv ./backup/docker-backup.new ./backup/docker-backup
        else
                rm ./backup/docker-backup.new
		exit
        fi

docker buildx build . \
	-t "crockerish/docker-backup:$version"

