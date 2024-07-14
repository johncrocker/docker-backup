#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

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

function getcontainernetworks() {
	local containername
	containername="$1"

	docker network inspect $(docker network ls -q --no-trunc) --format "{{\$v:=.Name}}{{ range .Containers }}{{if eq .Name \"$containername\" }}{{printf \$v}}{{end}}{{end}}" | sed -e '/^$/d' | sort -u
}

function gettargetdir() {
	local target
	local targetdir
	target="$1"
	targetdir="$(dirname "$target")"
	targetdir=$(realpath -q "$(dirname "$target")" 2>/dev/null)
	echo "$targetdir"
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

function slack_webhook() {
	local title
	local message
	local type
	title="$1"
	message="$2"
	silent="$4"
	type="$3"

	if [[ "$NOTIF_SLACK_WEBHOOK_ENABLE" = "true" ]]; then
		if [ -z "$silent" ]; then
			log "trace" "Notifying via Slack Webhook"
		fi

		curl -S -s -o /dev/null -X POST \
			-H 'Content-type: application/json' \
			--data "{\"text\":\"$title\n$message\"}" \
			"$NOTIF_SLACK_WEBHOOK_URL"
	fi
}

function pushover_notify() {
	local title
	local message
	local priority
	local type
	title="$1"
	message="$2"
	priority="$NOTIF_PUSHOVER_PRIORITY"
	silent="$4"
	type="$3"

	if [[ "$NOTIF_PUSHOVER_ENABLE" = "true" ]]; then
		if [ -z "$silent" ]; then
			log "trace" "Notifying via Pushover"
		fi

		curl -S -s -o /dev/null \
			--form-string "token=$NOTIF_PUSHOVER_APP_TOKEN" \
			--form-string "user=$NOTIF_PUSHOVER_USER_KEY" \
			--form-string "message=$message" \
			--form-string "title=$title" \
			--form-string "priority=$priority" \
			https://api.pushover.net/1/messages.json
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

	if [ "$PARAM_SIMULATE" = "true" ]; then
		title="$1 (Simulation)"
	fi

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
	pushover_notify "$title" "$message" "$type" "$silent"
	slack_webhook "$title" "$message" "$type" "$silent"
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

function getcontainersusingvolume() {
	local volume
	volume="$1"
	# shellcheck disable=SC2046
	docker container inspect $(docker ps --no-trunc -q) -f "{{\$v:=.Name}}{{ range .Mounts }}{{ if eq .Type \"volume\" }}{{ if eq .Name \"$volume\" }}{{\$v}}{{printf \"\\n\"}}{{ end }}{{ end }}{{ end }}" | cut -c2- | grep -v '^$' | sort
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")

	log "trace" "Backing up networks to $target"
	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"
		touch "$target"
		for networkid in $(docker network ls -q --no-trunc); do
			getnetwork "$networkid" >>"$target"
			echo "" >>"$target"
		done
	fi
}

function getcontainermounts() {
	local id
	id="$1"
	docker container inspect "$id" -f '{{$v:=.Name}}{{ range .Mounts }}{{$v}}{{printf ","}}{{.Type}}{{printf ","}}{{ .Source }}{{printf ","}}{{.Name}}{{printf ","}}{{.Destination}}{{printf "\n"}}{{ end }}' | cut -c2- | sed -e '$ d' | sort
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")

	log "trace" "Backing up working directory"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"

		case "$targetfile" in
		*.tar.gz)
			tar -czf "$target" -C "$workingdir" .
			;;
		*.tar.bz2)
			tar -cf - -C "$workingdir" . | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
			;;
		*.tar.xz)
			tar -cf - -C "$workingdir" . | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target"
			;;
		*)
			tar -cf "$target" -C "$workingdir" .
			;;
		esac
	fi

}

function backupvolumebypath() {
	local volume
	local volumepath
	local target
	local targetdir
	local targetfile
	volume="$1"
	target="$2"

	targetdir="$(dirname "$target")"
	if [ -d "$targetdir" ]; then
		targetdir=$(gettargetdir "$target")
	fi

	targetfile=$(basename "$target")
	volumepath="$BACKUP_SOURCE"$(docker volume ls --format '{{.Mountpoint}}' -f "Name=$volume")

	log "trace" "Backing up volume mount $volume"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"

		if [ ! -d "$volumepath" ]; then
			log "warn" "Cannot reach mount via filesystem. Using Docker method."
			backupvolumewithdocker "$volume" "$target"
			return
		fi

		log "trace" "Using path: $volumepath"

		case "$targetfile" in
		*.tar.gz)
			tar -cf - -C "$volumepath" . | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target"
			;;
		*.tar.bz2)
			tar -cf - -C "$volumepath" . | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
			;;
		*.tar.xz)
			tar -cf - -C "$volumepath" . | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target"
			;;
		*)
			tar -cf "$target" -C "$volumepath" .
			;;
		esac
	fi

}

function backupvolumewithdocker() {
	local volume
	local target
	local targetdir
	local targetfile
	volume="$1"
	target="$2"
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")

	log "trace" "Backing up volume mount $volume"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"
		case "$targetfile" in
		*.tar.gz)
			docker run --rm --name volumebackup \
				-v "$volume":/source:ro \
				"$BACKUP_DOCKERIMAGE" \
				tar -cf - -C /source/ . | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target"
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
				-e BACKUP_COMPRESS_XZ_OPT="$BACKUP_COMPRESS_XZ_OPT" \
				"$BACKUP_DOCKERIMAGE" \
				tar -cf - -C /source/ . | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target"
			;;
		*)
			docker run --rm --name volumebackup \
				-v "$volume":/source:ro \
				"$BACKUP_DOCKERIMAGE" \
				tar -cf - -C /source/ . >"$target"
			;;
		esac
	fi
}

function backupbind() {
	local source
	local target
	local targetdir
	local targetfile
	source="$1"
	target="$2"
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")

	log "trace" "Backing up bind mount $source"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"

		case "$targetfile" in
		*.tar.gz)
			tar -czf "$target" -C "$source" .
			;;
		*.tar.bz2)
			tar -cf - -C "$source" . | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target"
			;;
		*.tar.xz)
			tar -cf - -C "$source" . | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target"
			;;
		*)
			tar -cf "$target" -C "$source" .
			;;
		esac
	fi
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)
	tag="docker-backup/$containername:latest"

	log "trace" "Committing container $containername to local registry as $tag"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"
		docker container commit "$id" "$tag"

		case "$targetfile" in
		*.tar.gz) docker image save "$tag" | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target" ;;
		*.tar.bz2) docker image save "$tag" | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
		*.tar.xz) docker image save "$tag" | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target" ;;
		*) docker image save "$tag" >"$target" ;;
		esac

		docker image rm "$tag"
	fi
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)
	cmd=$(containerwhich "$id" "pg_dumpall")

	if [ -z "$cmd" ]; then
		log "error" "Cannot Backup postgres data in $containername, pg_dumpall missing"
	else
		log "trace" "Backing up postgres data in $containername"

		if [[ "$PARAM_SIMULATE" = "" ]]; then
			mkdir -p "$targetdir"
			case "$targetfile" in
			*.sql.gz) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target" ;;
			*.sql.xz) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target" ;;
			*.sql.bz2) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
			*) docker exec "$id" sh -c 'pg_dumpall --inserts -U $POSTGRES_USER ' >"$target" ;;
			esac
		fi
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)
	cmd=$(containerwhich "$id" "mariadb-dump")

	if [ -z "$cmd" ]; then
		log "error" "Cannot Backup mariadb data in $containername, mariadb-dump missing"
	else
		log "trace" "Backing up mariadb data in $containername"

		if [[ "$PARAM_SIMULATE" = "" ]]; then
			mkdir -p "$targetdir"
			case "$targetfile" in
			*.sql.gz) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target" ;;
			*.sql.xz) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target" ;;
			*.sql.bz2) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
			*) docker exec "$id" sh -c 'mariadb-dump -u root  --all-databases' >"$target" ;;
			esac
		fi
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
	targetdir=$(gettargetdir "$target")
	targetfile=$(basename "$target")
	containername=$(docker container inspect "$id" --format '{{.Name}}' | cut -c2-)

	log "trace" "Backing up container $containername"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$targetdir"
		docker container inspect "$id" | jq >"$targetdir"/container.json

		for network in $(getcontainernetworks "$containername"); do
			if [ ! -f "$targetdir"/networks.sh ]; then
				touch "$targetdir"/networks.sh
			fi

			getnetwork "$network" >>"$targetdir"/networks.sh
			echo "" >>"$targetdir"/networks.sh
		done

		case "$targetfile" in
		*.tar.gz) docker container export "$id" | gzip "$BACKUP_COMPRESS_GZ_OPT" - >"$target" ;;
		*.tar.xz) docker container export "$id" | xz -z "$BACKUP_COMPRESS_XZ_OPT" - >"$target" ;;
		*.tar.bz2) docker container export "$id" | bzip2 -z "$BACKUP_COMPRESS_BZ2_OPT" - >"$target" ;;
		*) docker container export "$id" >"$target" ;;
		esac
	fi
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

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$target"/"$containername"/"volumes"
		mkdir -p "$target"/"$containername"/"binds"
	fi

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
			log "trace" "Output file: $filename"

			if [[ "$BACKUP_PAUSECONTAINERS" = "true" ]]; then
				log "trace" "Stopping containers using volume $volumename before volume backup"
				volumecontainers=$(getcontainersusingvolume "$volumename")

				echo "$volumecontainers" | while IFS= read -r volumecontainer; do
					log "trace" "Stopping container $volumecontainer to backup volume $volumename"
					[ "$PARAM_SIMULATE" = "" ] && (docker stop "$volumecontainer")
				done

				backupvolumebypath "$volumename" "$filename"

				log "trace" "Starting containers using volume $volumename after volume backup"

				echo "$volumecontainers" | while IFS= read -r volumecontainer; do
					log "trace" "Starting container $volumecontainer after backup volume $volumename"
					[ "$PARAM_SIMULATE" = "" ] && (docker start "$volumecontainer")
				done
			else
				backupvolumebypath "$volumename" "$filename"
			fi
			;;
		esac
	done

	backupcontainer "$container" "$target"/"$containername"/"container$(tarext)"

	if [ "$(containerwhich "$container" 'psql')" ]; then
		backuppostgres "$container" "$target"/"$containername"/"data/postgres-data.sql$(compext)"
	fi

	if [ "$(containerwhich "$container" 'mariadb')" ]; then
		backupmariadb "$container" "$target"/"$containername"/"data/mariadb-data.sql$(compext)"
	fi

	if [[ "$workingdir" != "" ]]; then
		backupworkingdir "$workingdir" "$target"/"$containername"/"working_dir$(tarext)"
	fi

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		if [[ "$envfile" != "" ]]; then
			filename=$(basename "$envfile")
			cp "$BACKUP_SOURCE""$envfile" "$target"/"$containername"/"$filename"
		fi

		if [[ "$configfile" != "" ]]; then
			filename=$(basename "$configfile")
			cp "$BACKUP_SOURCE""$configfile" "$target"/"$containername"/"$filename"
		fi
	fi
}

function backupsystem() {
	local backuptarget
	backuptarget="$1"
	docker system info -f 'json' | jq >"$backuptarget"/dockersystem.json
	docker version -f 'json' | jq >"$backuptarget"/version.json

	if [ -f "$BACKUP_SOURCE"/etc/docker/daemon.json ]; then
		log "trace" "Backing up daemon.json"
		[ "$PARAM_SIMULATE" = "" ] && (cat "$BACKUP_SOURCE"/etc/docker/daemon.json | jq >"$backuptarget"/daemon.json)
	fi

	if [ -f "$BACKUP_SOURCE""$HOME"/.docker/config.json ]; then
		log "trace" "Baking up config.json"
		[ "$PARAM_SIMULATE" = "" ] && (cat "$BACKUP_SOURCE""$HOME"/.docker/config.json | jq >"$backuptarget"/config.json)
	fi
}

function parsearguments() {
	PARAM_SIMULATE=""

	for arg in "$@"; do
		key=$(echo "$arg" | cut -c 3- | cut -d "=" -f1)
		value=$(echo "$arg" | cut -d "=" -f2-)
		case "$key" in
		simulate)
			log "trace" "Simulating a backup - not writing any data"
			PARAM_SIMULATE="true"
			;;
		esac
	done
}

function main() {
	containertobackup="$BACKUP_CONTAINERS"
	backuptarget="$BACKUP_STORE"/"$BACKUPDATE"

	parsearguments "$@"

	if [[ "$PARAM_SIMULATE" = "" ]]; then
		mkdir -p "$backuptarget"
	fi

	log "trace" "Backup output folder: $backuptarget"

	if [[ "$BACKUP_RETENTION_DAYS" != "" ]]; then
		log "debug" "Deleting backup sets older than $BACKUP_RETENTION_DAYS days"
		ctime=$(("$BACKUP_RETENTION_DAYS" - 1))
		count=$(find "$BACKUP_STORE"/* -maxdepth 0 -type d -ctime +"$ctime" | wc -l)

		if [[ count -ge 1 ]]; then
			log "debug" "Found $count backup sets to delete."
			if [ "$PARAM_SIMULATE" = "" ]; then
				find "$BACKUP_STORE"/* -maxdepth 0 -type d -ctime +"$ctime" -exec rm -rf {} +
			fi
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

	notify "docker-backup" "Backup operation finished" "success"
	log "trace" "Finished."
}

BACKUPDATE="$(date '+%Y%m%d-%H%M')"

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
