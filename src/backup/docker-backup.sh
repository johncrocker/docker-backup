#!/usr/bin/env bash
# shellcheck disable=SC2317  # Don't warn about unreachable commands in this file

function log() {
	declare -A loglevels
	declare -A logcolours
	declare -A notifloglevels
	local level
	local colour
	local levelstr
	local message
	local configuredlevel
	local padding
	local configloglevel
	local configurednotiflevel
	local notifloglevel
	notifloglevels=([fatal]="failure" [error]="failure" [warn]="warning" [info]="info" [debug]="info" [trace]="success")
	loglevels=([fatal]=1 [error]=2 [warn]=3 [info]=4 [debug]=5 [trace]=6)
	logcolours=([fatal]="\e[1;31m" [error]="\e[31m" [warn]="\e[1;37m" [info]="\e[1;33m" [debug]="\e[0m" [trace]="\e[0m")
	configloglevel="$BACKUP_LOGLEVEL"

	if [[ "$configloglevel" = "" ]]; then
		configloglevel="trace"
	fi

	configuredlevel=${loglevels["$configloglevel"]}
	level=${loglevels["$1"]}
	colour=${logcolours["$1"]}
	notifloglevel=${notifloglevels["$1"]}
	levelstr=$(echo "$1" | awk '{ print toupper($0) }')
	message="$2"
	padding="      "

	if [[ ("$level" -lt "$configuredlevel") || ("$level" = "$configuredlevel") ]]; then
		printf "%b%s %s : %s \e[0m\n" "$colour" "$(date '+%Y-%m-%d %H:%M:%S')" "${padding:${#levelstr}}$levelstr" "$message"
	fi

	if [[ "$NOTIF_LOGLEVEL" != "" ]]; then
		configurednotiflevel=${loglevels["$NOTIF_LOGLEVEL"]}
		if [[ ("$level" -lt "$configurednotiflevel") || ("$level" = "$configurednotiflevel") ]]; then
			notify "docker-backup" "$levelstr\n$message" "$notifloglevel" "true"
		fi
	fi
}

function compext() {

	if [[ "$BACKUP_COMPRESS" = "true" ]]; then
		case "$BACKUP_COMPRESS_METHOD" in
		gzip)
			echo ".gz"
			;;
		bzip2)
			echo ".bz2"
			;;
		xz)
			echo ".xz"
			;;
		*)
			echo ".gz"
			;;
		esac
	else
		echo ""
	fi
}

function tarext() {

	if [[ "$BACKUP_COMPRESS" = "true" ]]; then
		case "$BACKUP_COMPRESS_METHOD" in
		gzip)
			echo ".tar.gz"
			;;
		bzip2)
			echo ".tar.bz2"
			;;
		xz)
			echo ".tar.xz"
			;;
		*)
			echo ".tar.gz"
			;;
		esac
	else
		echo ".tar"
	fi
}

function apprise_notify() {
	local title
	local message
	local silent
	local type
	title="$1"
	message="$2"
	silent="$4"
	type="$3"

	if [[ "$type" = "" ]]; then
		type="info"
	fi

	if [[ "$NOTIF_APPRISE_ENABLE" = "true" ]]; then

		if [ -z "$silent" ]; then
			log "trace" "Notifying via Apprise"
		fi

		curl -S -s -o /dev/null -X POST \
			-d "{\"urls\": \"$NOTIF_APPRISE_URLS\",\"body\":\"$message\",\"title\":\"$title\", \"type\": \"$type\"}" \
			-H "Content-Type: application/json" \
			"$NOTIF_APPRISE_SERVER_URL""/notify/"
	fi
}

function mattermost_notify() {
	local title
	local message
	local silent
	local type
	title="$1"
	message="$2"
	silent="$4"
	type="$3"

	if [[ "$NOTIF_MATTERMOST_ENABLE" = "true" ]]; then
		if [ -z "$silent" ]; then
			log "trace" "Notifying via Mattermost"
		fi
		curl -S -s -o /dev/null -i -X POST -H 'Content-Type: application/json' \
			-d "{\"text\": \"$title\n$message\"}" \
			"https://$NOTIF_MATTERMOST_HOST/hooks/$NOTIF_MATTERMOST_KEY"
	fi
}

function discord_notify() {
	local title
	local message
	local silent
	local type
	title="$1"
	message="$2"
	silent="$4"
	type="$3"

	if [[ "$NOTIF_DISCORD_ENABLE" = "true" ]]; then
		if [ -z "$silent" ]; then
			log "trace" "Notifying via Discord"
		fi
		#curl -S -s -o /dev/null
		curl -H 'Content-Type: application/json' \
			-d "{\"username\": \"docker-backup\", \"content\": \"$title\n$message\"}" \
			"https://discord.com/api/webhooks/$NOTIF_DISCORD_WEBHOOK_ID/$NOTIF_DISCORD_TOKEN"
	fi
}

function gotify_notify() {
	local title
	local message
	local priority
	local siylent
	local type
	title="$1"
	message="$2"
	priority="$NOTIF_GOTIFY_PRIORITY"
	silent="$4"
	type="$3"

	if [[ "$NOTIF_GOTIFY_ENABLE" = "true" ]]; then
		if [ -z "$silent" ]; then
			log "trace" "Notifying via Gotify"
		fi

		curl -S -s -o /dev/null -X POST \
			-F "title=$title" \
			-F "message=$message" \
			-F "priority=$priority" \
			"$NOTIF_GOTIFY_SERVER_URL""/message?token=$NOTIF_GOTIFY_TOKEN"
	fi
}

function notify() {
	local title
	local message
	local silent
	local type
	title="$1"
	message="$2"
	silent="$4"
	type="$3"

	if [ -z "$type" ]; then
		type="info"
	fi

	if [ -z "$silent" ]; then
		log "trace" "Notify: $title - $message"
	fi

	gotify_notify "$title" "$message" "$type" "$silent"
	discord_notify "$title" "$message" "$type" "$silent"
	apprise_notify "$title" "$message" "$type" "$silent"
	mattermost_notify "$title" "$message" "$type" "$silent"
}

function readenvironmentfile() {
	local filename
	filename="%$1"

	if [[ ! -f "$filename" ]]; then
		filename="./docker-backup.env"
	fi

	if [[ -f "$filename" ]]; then
		log "trace" "Using settings from Env File: $filename"
		set -a
		source "$filename"
		set +a
	fi
}

function getvolumelabelvalue() {
	local volume
	local label
	local default
	local value
	volume="$1"
	label="$2"
	default="$3"

	value=$(docker volume inspect "$volume" --format "{{range \$k,\$v:=.Labels}}{{ if eq (\$k) \"$label\" }}{{ \$v }}{{end}}{{end}}")

	if [[ "$value" = "" ]]; then
		value="$default"
	fi
	echo "$value"
}

function getcontainerlabelvalue() {
	local container
	local label
	local default
	local value
	container="$1"
	label="$2"
	default="$3"

	value=$(docker container inspect "$container" --format "{{range \$k,\$v:=.Config.Labels}}{{ if eq (\$k) \"$label\" }}{{ \$v }}{{end}}{{end}}")

	if [[ "$value" = "" ]]; then
		value="$default"
	fi
	echo "$value"
}

function getnetprop() {
	docker network inspect "$1" --format "$2"
}

function getnetwork() {
	local network
	network="$1"
	echo "# Docker network create script for network $network"
	echo "docker network create $(getnetprop "$network" '{{.Name}}') \\"
	echo "  --driver $(getnetprop "$network" '{{.Driver}}') \\"
	echo "  --scope $(getnetprop "$network" '{{.Scope}}') \\"

	if [[ "$(getnetprop "$network" '{{.EnableIPv6}}')" = "true" ]]; then
		echo "  --ipv6 \\"
	fi

	if [[ "$(getnetprop "$network" '{{.Attachable}}')" = "true" ]]; then
		echo "  --attachable \\"
	fi

	if [[ "$(getnetprop "$network" '{{.Internal}}')" = "true" ]]; then
		echo "  --internal \\"
	fi

	echo "  --ipam-driver $(getnetprop "$network" '{{.IPAM.Driver}}') \\"
	echo "  --subnet $(getnetprop "$network" '{{range .IPAM.Config}}{{.Subnet}}{{end}}') \\"
	echo "  --gateway $(getnetprop "$network" '{{range .IPAM.Config}}{{.Gateway}}{{end}}') "
}

function backupnetworks() {
	local target
	local targetfile
	local targetdir
	target="$1"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")

	mkdir -p "$targetdir"
	touch "$target"
	for networkid in $(docker network ls -q --no-trunc); do
		getnetwork "$networkid" >>"$target"
		echo "" >>"$target"
	done
}

function getcontainermounts() {
	local id
	id="$1"
	docker inspect "$id" -f '{{$v:=.Name}}{{ range .Mounts }}{{$v}}{{printf ","}}{{.Type}}{{printf ","}}{{ .Source }}{{printf ","}}{{.Name}}{{printf ","}}{{.Destination}}{{printf "\n"}}{{ end }}' | cut -c2- | sed -e '$ d' | sort
}

function getcontainers() {
	docker ps -q --no-trunc -a
}

function getcontainernames() {
	docker ps -a --format '{{.Names}}' | sort
}

function getcontainermountlist() {
	for id in $(getcontainers); do
		getcontainermounts "$id"
	done | cut -c 3- | sort
}

function backupworkingdir() {
	local workingdir
	local target
	local targetdir
	local targetfile
	workingdir="$BACKUP_SOURCE""$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")

	log "trace" "Backing up working directory"
	mkdir -p "$targetdir"

	case "$targetfile" in
	*.tar.gz)
		tar -czf "$target" -C "$workingdir" .
		;;
	*.tar.bz2)
		tar -cf - -C "$workingdir" . | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
		;;
	*.tar.xz)
		tar -cf - -C "$workingdir" . | xz -z "$XZ_OPT" - >"$target"
		;;
	*)
		tar -cf "$target" -C "$workingdir" .
		;;
	esac
}

function backupvolume() {
	local volume
	local target
	local targetdir
	local targetfile
	local volumetype
	volume="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")
	volumetype=$(getvolumelabelvalue "$volume" "guidcruncher.dockerbackup.type" "generic")

	mkdir -p "$targetdir"
	log "trace" "Backing up volume mount $volume (type=$volumetype)"

	case "$targetfile" in
	*.tar.gz)
		docker run --rm --name volumebackup \
			-v "$volume":/source:ro \
			"$BACKUP_DOCKERIMAGE" \
			tar -cf - -C /source/ . | gzip >"$target"
		;;
	*.tar.bz2)
		docker run --rm --name volumebackup \
			-v "$volume":/source:ro \
			-e BACKUP_COMPRESS_BZ2_OPT="$BACKUP_COMPRESS_BZ2_OPT" \
			"$BACKUP_DOCKERIMAGE" \
			tar -cf - -C /source/ . bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
		;;
	*.tar.xz)
		docker run --rm --name volumebackup \
			-v "$volume":/source:ro \
			-e XZ_OPT="$XZ_OPT" \
			"$BACKUP_DOCKERIMAGE" \
			tar -cf - -C /source/ . | xz -z "$XZ_OPT" - >"$target"
		;;
	*)
		docker run --rm --name volumebackup \
			-v "$volume":/source:ro \
			"$BACKUP_DOCKERIMAGE" \
			tar -cf - -C /source/ . >"$target"
		;;
	esac

}

function backupbind() {
	local source
	local target
	local targetdir
	local targetfile
	local volumetype
	source="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")

	volumetype=$(getvolumelabelvalue "$volume" "guidcruncher.dockerbackup.type" "generic")

	mkdir -p "$targetdir"
	log "trace" "Backing up bind mount $source"

	case "$targetfile" in
	*.tar.gz)
		tar -czf "$target" -C "$source" .
		;;
	*.tar.bz2)
		tar -cf - -C "$source" . | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
		;;
	*.tar.xz)
		tar -cf - -C "$source" . | xz -z "$XZ_OPT" - >"$target"
		;;
	*)
		tar -cf "$target" -C "$source" .
		;;
	esac

}

function commitcontainer() {
	local id
	local target
	local targetdir
	local targetfile
	local containername
	local tag
	id="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)

	mkdir -p "$targetdir"
	tag="docker-backup/$containername:latest"
	log "trace" "Committing container $containername to local registry as $tag"
	docker container commit "$id" "$tag"

	case "$targetfile" in
	*.tar.gz) docker image save "$tag" | gzip >"$target" ;;
	*.tar.bz2) docker image save "$tag" | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
	*.tar.xz) docker image save "$tag" | xz -z "$XZ_OPT" - >"$target" ;;
	*) docker image save "$tag" >"$target" ;;
	esac

	docker image rm "$tag"
}

function containerwhich() {
	local id
	local cmd
	local result
	id="$1"
	cmd="$2"
	result=$(docker exec "$id" sh -c "which $cmd 2> /dev/null")

	if echo "$result" | grep -q "exec failed"; then
		echo ""
	else
		echo "$result"
	fi
}

function backuppostgres() {
	local id
	local target
	local targetdir
	local targetfile
	local containername
	local cmd
	id="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)
	cmd=$(containerwhich "$id" "pg_dumpall")

	if [ -z "$cmd" ]; then
		log "error" "Cannot Backup postgres data in $containername, pg_dumpall missing"
	else
		mkdir -p "$targetdir"
		log "trace" "Backing up postgres data in $containername"
		echo $target
		case "$targetfile" in
		*.sql.gz) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | gzip >"$target" ;;
		*.sql.xz) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | xz -z "$XZ_OPT" - >"$target" ;;
		*.sql.bz2) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
		*) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' >"$target" ;;
		esac
	fi

}

function backupmariadb() {
	local id
	local target
	local targetdir
	local targetfile
	local containername
	local cmd
	id="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)
	cmd=$(containerwhich "$id" "mariadb-dump")

	if [ -z "$cmd" ]; then
		log "error" "Cannot Backup mariadb data in $containername, mariadb-dump missing"
	else
		mkdir -p "$targetdir"
		log "trace" "Backing up mariadb data in $containername"

		case "$targetfile" in
		*.sql.gz) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | gzip >"$target" ;;
		*.sql.xz) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | xz -z "$XZ_OPT" - >"$target" ;;
		*.sql.bz2) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
		*) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' >"$target" ;;
		esac
	fi

}

function backupcontainer() {
	local id
	local target
	local targetdir
	local targetfile
	local containername
	id="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)

	mkdir -p "$targetdir"
	log "trace" "Backing up container $containername"

	case "$targetfile" in
	*.tar.gz) docker container export "$id" | gzip >"$target" ;;
	*.tar.xz) docker container export "$id" | xz -z "$XZ_OPT" - >"$target" ;;
	*.tar.bz2) docker container export "$id" | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
	*) docker container export "$id" >"$target" ;;
	esac

}

function dockerbackup() {
	local container
	local containerid
	local target
	local containername
	local exclude
	local workingdir
	local configfile
	local envfile
	container="$1"
	target="$2"
	containername=$(docker container inspect "$container" --format '{{.Name}}' | cut -c2-)
	containerid=$(docker container inspect "$container" --format '{{.Id}}')
	exclude=$(getcontainerlabelvalue "$container" "guidcruncher.dockerbackup.exclude" "false")
	workingdir=$(getcontainerlabelvalue "$container" "com.docker.compose.project.working_dir" "")
	configfile=$(getcontainerlabelvalue "$container" "com.docker.compose.project.config_files" "")
	envfile=$(getcontainerlabelvalue "$container" "com.docker.compose.project.environment_file" "")

	if [[ "$containerid" = "$DOCKER_BACKUP_CONTAINERID" ]]; then
		log "info" "Skipping container : $containername - Its running the docker-backup process."
		return 1
	fi

	if [[ "$exclude" = "true" ]]; then
		log "info" "Container excluded from backup: $containername"
		return 1
	fi

	mkdir -p "$target"/"$containername"/"volumes"
	mkdir -p "$target"/"$containername"/"binds"

	log "trace" "Backing up volumes for $containername"

	getcontainermounts "$container" | while read -r line; do
		type=$(echo "$line" | cut -d$',' -f2)
		hostsource=$(echo "$line" | cut -d$',' -f3)
		volumename=$(echo "$line" | cut -d$',' -f4)
		containertarget=$(echo "$line" | cut -d$',' -f5)
		log "trace" "  $type $hostsource":"$containertarget"

		case "$type" in
		bind)
			filename="$target"/"$containername"/binds/"$volumename""$(tarext)"
			;;
		volume)
			filename="$target"/"$containername"/volumes/"$volumename""$(tarext)"
			backupvolume "$volumename" "$filename"
			;;
		esac
	done

	backupcontainer "$container" "$target"/"$containername"/"container$(tarext)"

	if [ $(containerwhich "$container" "psql") ]; then
		backuppostgres "$container" "$target"/"$containername"/"data/postgres-data.sql$(compext)"
	fi

	if [ $(containerwhich "$container" "mariadb") ]; then
		backupmariadb "$container" "$target"/"$containername"/"data/mariadb-data.sql$(compext)"
	fi

	if [[ "$workingdir" != "" ]]; then
		backupworkingdir "$workingdir" "$target"/"$containername"/"working_dir$(tarext)"
	fi

	if [[ "$envfile" != "" ]]; then
		filename=$(basename "$envfile")
		cp "$BACKUP_SOURCE""$envfile" "$target"/"$containername"/"$filename"
	fi

	if [[ "$configfile" != "" ]]; then
		filename=$(basename "$configfile")
		cp "$BACKUP_SOURCE""$configfile" "$target"/"$containername"/"$filename"
	fi
}

function backupsystem() {
	local backuptarget
	backuptarget="$1"
	docker system info -f 'json' | jq >"$backuptarget"/dockersystem.json
	docker version -f 'json' | jq >"$backuptarget"/version.json

	if [ -f "$HOME"/.docker/config.json ]; then
		sudo cat "$HOME"/.docker/config.json | jq >"$backuptarget"/config.json
	fi
}

function main() {
	XZ_OPT_STORE="$XZ_OPT"
	XZ_OPT="$BACKUP_COMPRESS_XZ_OPT"
	containertobackup="$1"
	backuptarget="$BACKUP_STORE"/"$(date '+%Y%m%d-%H%M')"
	mkdir -p "$backuptarget"

	if [[ "$BACKUP_RETENTION_DAYS" != "" ]]; then
		log "debug" "Deleting backup sets older than $BACKUP_RETENTION_DAYS days"
		count=$(find "$BACKUP_STORE"/* -maxdepth 0 -type d -ctime +"$BACKUP_RETENTION_DAYS" | wc -l)

		if [[ count -ge 1 ]]; then
			log "debug" "Found $count backup sets to delete."
			find "$BACKUP_STORE"/* -maxdepth 0 -type d -ctime +"$BACKUP_RETENTION_DAYS" -exec rm -rf {} +
		else
			log "debug" "No old backup sets found"
		fi
	fi

	log "trace" "Backing up to target $backuptarget"
	notify "docker-backup" "Starting backup to $backuptarget" "info"

	backupnetworks "$backuptarget""/networks.sh"
	backupsystem "$backuptarget"

	if [[ "$containertobackup" = "" ]]; then
		notify "docker-backup" "Performing full backup" "info"
		for containername in $(getcontainernames); do
			dockerbackup "$containername" "$backuptarget"
		done
	else
		notify "docker-backup" "Performing partial backup of $containertobackup" "info"
		dockerbackup "$containertobackup" "$backuptarget"
	fi

	# sudo chown "$(id -u)":"$(id -g)" "$backuptarget" -R

	XZ_OPT="$XZ_OPT_STORE"

	notify "docker-backup" "Backup operation finished" "success"
	log "trace" "Finished."
}

envfile="$1"

if [[ "$envfile" = "" ]]; then
	envfile="./docker-backup.env"
fi

readenvironmentfile "$envfile"

if [ "$EUID" -ne 0 ]; then
	log "fatal" "Cannot start. Process must be run as root user or via sudo."
	notify "docker-backup" "FATAL: Cannot start. Process must be run as root user or via sudo." "failure"
	exit 1
fi

if pidof "docker-backup.sh" >/dev/null; then
	log "fatal" "Cannot start. Backup process is already running."
	notify "docker-backup" "FATAL: Cannot start. Backup process is already running." "failure"
	exit 1
fi

main "$@"
exit 0
