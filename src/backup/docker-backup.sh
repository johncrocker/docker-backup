#!/usr/bin/env bash

function log() {
	declare -A loglevels
	declare -A logcolours
	local leve
	local colour
	local levelstr
	local message
	local configuredlevel
	local padding
	local configloglevel
	loglevels=([fatal]=1 [error]=2 [warn]=3 [info]=4 [debug]=5 [trace]=6)
	logcolours=([fatal]="\e[1;31m" [error]="\e[31m" [warn]="\e[1;37m"[info]="\e[1;33m" [debug]="\e[0m" [trace]="\e[0m")
	configloglevel="$BACKUP_LOGLEVEL"

	if [[ "$configloglevel" = "" ]]; then
		configloglevel="trace"
	fi

	configuredlevel=${loglevels["$configloglevel"]}
	level=${loglevels["$1"]}
	colour=${logcolours["$1"]}
	levelstr=$(echo "$1" | awk '{ print toupper($0) }')
	message="$2"
	padding="      "

	if [[ ("$level" -lt "$configuredlevel") || ("$level" = "$configuredlevel") ]]; then
		printf "%b%s %s : %s \e[0m\n" "$colour" "$(date '+%Y-%m-%d %H:%M:%S')" "${padding:${#levelstr}}$levelstr" "$message"
	fi
}

function tarext() {

	if [[ "$BACKUP_CONPRESS" = "true" ]]; then
		echo ".tar.gz"
	else
		echo ".tar"
	fi
}

function apprise_notify() {
	local title
	local message
	title="$1"
	message="$2"

	if [[ "$NOTIF_APPRISE_ENABLE" = "true" ]]; then
		log "trace" "Notifying via Apprise"
		curl -S -s -o /dev/null -X POST \
			-F "body=$message" \
			-F "tags=$NOTIF_APPRISE_TAGS" \
			"$NOTIF_APPRISE_URL""/notify/apprise"
	fi
}

function gotify_notify() {
	local title
	local message
	local priority
	title="$1"
	message="$2"
	priority="5"

	if [[ "$NOTIF_GOTIFY_ENABLE" = "true" ]]; then
		log "trace" "Notifying via Gotify"
		curl -S -s -o /dev/null -X POST \
			-F "title=$title" \
			-F "message=$message" \
			-F "priority=$priority" \
			"$NOTIF_GOTIFY_URL""/message?token=$NOTIF_GOTIFY_TOKEN"
	fi
}

function notify() {
	local title
	local message
	title="$1"
	message="$2"
	log "trace" "Notify: $title - $message"
	gotify_notify "$title" "$message"
	apprise_notify "$title" "$message"
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
	workingdir="$1"
	target="$2"
	targetdir=$(realpath "$(dirname "$target")")
	targetfile=$(basename "$target")

	log "trace" "Backing up working directory"
	mkdir -p "$targetdir"
	case "$targetfile" in
	*.tar.gz)
		sudo tar -czf "$target" -C "$workingdir" .
		;;
	*)
		sudo tar -cf "$target" -C "$workingdir" .
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
			-v "$targetdir":/target \
			"$BACKUP_DOCKERIMAGE" \ 
			tar -czf /target/"$targetfile" -C /source/ .
		;;
	*)
		docker run --rm --name volumebackup \
			-v "$volume":/source:ro \
			-v "$targetdir":/target \
			"$BACKUP_DOCKERIMAGE" \
			tar -cf /target/"$targetfile" -C /source/ .
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
	*) docker image save "$tag" >"$target" ;;
	esac

	docker image rm "$tag"
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
	*) docker container export "$id" >"$target" ;;
	esac

}

function dockerbackup() {
	local container
	local target
	local containername
	local exclude
	local workingdir
	local configfile
	local envfile
	container="$1"
	target="$2"
	containername=$(docker container inspect "$container" --format '{{.Name}}' | cut -c2-)
	exclude=$(getcontainerlabelvalue "$container" "guidcruncher.dockerbackup.exclude" "false")
	workingdir=$(getcontainerlabelvalue "$container" "com.docker.compose.project.working_dir" "")
	configfile=$(getcontainerlabelvalue "$container" "com.docker.compose.project.config_files" "")
	envfile=$(getcontainerlabelvalue "$container" "com.docker.compose.project.environment_file" "")

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

	if [[ "$workingdir" != "" ]]; then
		backupworkingdir "$workingdir" "$target"/"$containername"/"working_dir$(tarext)"
	fi

	if [[ "$envfile" != "" ]]; then
		filename=$(basename "$envfile")
		cp "$envfile" "$target"/"$containername"/"$filename"
	fi

	if [[ "$configfile" != "" ]]; then
		filename=$(basename "$configfile")
		cp "$configfile" "$target"/"$containername"/"$filename"
	fi
}

function main() {
	envfile="$1"

	if [[ "$envfile" = "" ]]; then
		envfile="./docker-backup.env"
	fi

	readenvironmentfile "$envfile"

	containertobackup="$1"
	backuptarget="$BACKUP_STORE"/"$(date '+%Y%m%d_%H%M')"

	log "trace" "Backing up to target $backuptarget"
	notify "docker-backup" "Starting backup to $backuptarget"

	backupnetworks "$backuptarget""/networks.sh"

	if [[ "$containertobackup" = "" ]]; then
		notify "docker-backup" "Performing full backup"
		for containername in $(getcontainernames); do
			dockerbackup "$containername" "$backuptarget"
		done
	else
		notify "docker-backup" "Performing partial backup of $containertobackup"
		dockerbackup "$containertobackup" "$backuptarget"
	fi

	sudo chown "$(id -u)":"$(id -g)" "$backuptarget" -R
	notify "docker-backup" "Backup operation finished"
	log "trace" "Finished."
}

echo ""
echo "     _ ____  _  ___ "
echo "  __| | __ )| |/ / |"
echo " / _  |  _ \| ' /| |"
echo "| (_| | |_) | . \|_" |
	echo " \__,_|____/|_|\_(_)"
echo "Bike Riding"
echo ""
main $@
