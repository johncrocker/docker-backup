#!/bin/bash
version="$1"

if [ -z "$version" ]; then
	version="dev"
fi

cd $HOME/src/docker-backup/src

docker buildx create --name multiarchbuilder --use --bootstrap

docker buildx build --push . \
        --platform linux/amd64,linux/arm64 \
        -t "crockerish/docker-backup:$version"

docker buildx rm multiarchbuilder
