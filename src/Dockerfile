FROM alpine:3.20.1

RUN apk add --no-cache --update curl jq xz docker bash tzdata bzip2 run-parts

VOLUME /source
VOLUME /target
VOLUME /logs

RUN mkdir -p /etc/cron.schedule/cron.hourly
RUN mkdir -p /etc/cron.schedule/cron.daily
RUN mkdir -p /etc/cron.schedule/cron.weekly
RUN mkdir -p /etc/cron.schedule/cron.monthly

COPY ./crontab.txt /etc/crontab.default
VOLUME /etc/cron.schedule

ENV TZ=UTC
ENV BACKUP_RUN_ONCE="true"
ENV BACKUP_PAUSECONTAINERS="false"
ENV BACKUP_LOGLEVEL="trace"
ENV BACKUP_STORE="/target"
ENV BACKUP_SOURCE="/source"
ENV BACKUP_COMPRESS="false"
ENV BACKUP_COMPRESS_METHOD="gzip"
ENV BACKUP_COMPRESS_GZ_OPT="-6"
ENV BACKUP_COMPRESS_XZ_OPT=-"2 -T0"
ENV BACKUP_COMPRESS_BZ2_OPT=""
ENV BACKUP_DOCKERIMAGE="alpine:3.20.1"
ENV BACKUP_RETENTION_DAYS="0"

ENV NOTIF_LOGLEVEL="error"
ENV NOTIF_GOTIFY_ENABLE="false"
ENV NOTIF_GOTIFY_TOKEN=""
ENV NOTIF_GOTIFY_SERVER_URL=""
ENV NOTIF_GOTIFY_PRIORITY="5"
ENV NOTIF_APPRISE_ENABLE="false"
ENV NOTIF_APPRISE_URLS=""
ENV NOTIF_APPRISE_SERVER_URL=""
ENV NOTIF_MATTERMOST_ENABLE="false"
ENV NOTIF_MATTERMOST_HOST=""
ENV NOTIF_MATTERMOST_KEY=""
ENV NOTIF_DISCORD_ENABLE="false"
ENV NOTIF_DISCORD_WEBHOOK_ID=""
ENV NOTIF_DISCORD_TOKEN=""
ENV NOTIF_DISCORD_USERNAME=""
ENV NOTIF_PUSHOVER_ENABLE="false"
ENV NOTIF_PUSHOVER_APP_TOKEN=""
ENV NOTIF_PUSHOVER_USER_KEY=""
ENV NOTIF_PUSHOVER_PRIORITY="0"
ENV NOTIF_SLACK_WEBHOOK_ENABLE="false"
ENV NOTIF_SLACK_WEBHOOK_URL=""

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

COPY ./build/docker-backup.sh /app/docker-backup.sh
COPY ./build/docker-backup-cron.sh /app/docker-backup-cron.sh
COPY ./build/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/docker-backup.sh
RUN chmod +x /app/docker-backup-cron.sh 
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT [ "/app/entrypoint.sh" ]
CMD [ "--backup" ]
