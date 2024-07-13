#!/bin/bash

HOUR=$(date +%H)

if [[ "$HOUR" = "01" ]]; then
	cd /app
	./docker-backup-cron.sh
fi

