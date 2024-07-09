#!/bin/bash
version="$1"

	if [ -z "$version" ]; then
		version="dev"
	fi

docker buildx build . \
	-t "crockerish/docker-backup:$version"
