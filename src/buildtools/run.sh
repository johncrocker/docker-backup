#!/bin/bash
version="$1"
 
if [ -z "$version" ]; then
	version="devbuild"
fi

cd $HOME/src/docker-backup/src

docker run -it --rm --name docker-backup-test \
		-e TZ=Europe/London \
                -e BACKUP_LOGLEVEL=trace \
                -e BACKUP_PAUSECONTAINERS=false \
                -e BACKUP_COMPRESS=true \
                -e BACKUP_COMPRESS_METHOD=gzip \
                -e BACKUP_COMPRESS_XZ_OPT=-T0 \
                -e BACKUP_COMPRESS_BZ2_OPT=-2 \
                -e BACKUP_DOCKERIMAGE=alpine:3.20.1 \
                -e BACKUP_RETENTION_DAYS=1 \
                -e NOTIF_LOGLEVEL=error \
                -e NOTIF_GOTIFY_ENABLE=false \
                -e NOTIF_MATTERMOST_ENABLE=false \
                -e NOTIF_DISCORD_ENABLE=false \
		-e NOTIF_APPRISE_ENABLE=false \
                -e NOTIF_PUSHOVER_ENABLE=false \
                -e NOTIF_APPRISE_URLS=pover://ukmd45b1xhek1jbm4v9g83zzqxjzbm@a2ep2u3kuva7sauc6jx48dx4vb4nue?rto=30 \
                -e NOTIF_APPRISE_SERVER_URL=http://apprise.apps.home \
                -e TZ=Europe/London \
                -v /var/run/docker.sock:/var/run/docker.sock:ro \
                -v /:/source:ro \
                -v /media/external/docker-backup:/target \
                -v /media/logs:/logs \
		"crockerish/docker-backup:$version" \
		hedgedoc

