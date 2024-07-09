#!/bin/bash
version="$1"

	if [ -z "$version" ]; then
		version="latest"
	fi

docker buildx build . \
	-t "crockerish/docker-backup:$version"

docker run -d --rm --name docker-backup \
	--env-file ./backup/docker-backup-container.env \
	-e TZ=Europe/London \
	-v /var/run/docker.sock:/var/run/docker.sock:ro \
	-v /:/source:ro \
	-v /media/external/docker-backup:/target \
	"crockerish/docker-backup:$version"




			?				B					 
		
