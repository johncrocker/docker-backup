# docker-backup
Docker-Backup is a open source backup solution for your docker infrastructure. Written in BASH and designed to be sinple to use.

```bash
docker run -d --rm --name docker-backup \
        --env-file ./docker-backup.env \
        -e TZ=Europe/London \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /:/source:ro \
        -v /media/backup:/target \
	-v /root/logs:/logs \
	crockerish/docker-backup:latest
```
