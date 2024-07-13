#!/bin/bash

docker pull crockerish/docker-backup:latest

docker run -d --rm --name docker-backup \
     	-e TZ=Europe/London \
	-e BACKUP_RUN_ONCE=true \
	-e BACKUP_CONTAINERS= \
        -e BACKUP_LOGLEVEL=trace \
        -e BACKUP_PAUSECONTAINERS=true \
        -e BACKUP_COMPRESS=true \
        -e BACKUP_COMPRESS_METHOD=gzip \
        -e BACKUP_DOCKERIMAGE=alpine:3.20.1 \
        -e BACKUP_RETENTION_DAYS=1 \
  	-v /var/run/docker.sock:/var/run/docker.sock:ro \
  	-v /:/source:ro \
  	-v /media/external/docker-backup:/target \
        -v /media/logs:/logs \
  	crockerish/docker-backup:latest
