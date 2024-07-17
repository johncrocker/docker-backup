#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

function getlabels() {
	local json
	json="$1"
	echo "$json" | jq '.[].Config.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk '!/^(org.opencontainers|com.docker)/{printf ("      - \"%s=%s\"\n" ,$1,$2)}' | sort -u
}

function getcontainerlabelvalue() {
	local json
	local label
	json="$1"
	label="$2"
	echo "$json" | jq '.[].Config.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk -v label="$label" '$1==label { print $2 }'
}

function writeservicenetworks() {
	local json
	json="$1"

	printf "    %s:\n" "networks"

	echo "$json" | jq '.[].NetworkSettings.Networks | to_entries[] | [ (.key), (.value | .IPAddress) ] | @tsv ' -r |  awk '{ printf "      %s:\n        ipv4_address: %s\n", $1, $2 }'
}

function writeserviceexposedports() {
	local json
	json="$1"
	printf "    %s:\n" "expose"
	echo "$json" | jq '.[].Config.ExposedPorts | keys[] as $key | [ $key ] | @tsv' -r | awk '{printf("      - \"%s\"\n", $1)}'
}

function writeserviceports() {
	local json
	json="$1"
	printf "    %s:\n" "ports"
	echo "$json" | jq '.[].NetworkSettings.Ports | to_entries[] | [ (.key), (.value | .[]?.HostPort ), (.value | .[]?.HostIp ) ] | @tsv' -r | awk '! ( NF==1 )' | awk '{printf ("      - \"%s:%s: %s\"\n", $3,$2,$1)}'
}

function writeservicevolumes() {
	local json
	json="$1"

	printf "    %s:\n" "volumes"

	echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source, .[$key].Destination, .[$key].Mode] | @tsv' -r | sed '/^bind/d' | awk '{ printf "      - %s:%s:%s\n", $2, $4, $5 }'
	echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source,.[$key].Destination,.[$key].Mode] | @tsv' -r | sed '/^volume/d' | awk '{ printf "      - %s:%s:%s\n", $2, $3, $4 }'
}


function writeprop() {
	local json
	local prop
	local path
	local value
	json="$1"
	prop="$2"
	path="$3"

	value=$(echo "$json" | jq "$path" -r)
	if [[ ! -z "$value" ]]; then
		if [[ ! "$value" = "null" ]] && [[ ! "$value" = "[]" ]]; then
			if [[ "$value" =~ \[.* ]]; then
				value=$(echo "$json" | jq "$path | @tsv" -r)
				printf "    %s:\n" "$prop"
				echo "$value" | tr "\t" "\n" | sed -e 's/^/      - /'
			else
				printf "    %s: %s\n" "$prop" "$value"
			fi
		fi
	fi
}

function writeservice() {
	local json
	json="$1"
	labels=$(getlabels "$json")

	printf "  %s:\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
	printf "    image: %s\n" $(echo "$json" | jq .[].Config.Image -r)
	printf "    container_name: %s\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
	printf "    hostname: %s\n" $(echo "$json" | jq .[].Config.Hostname -r)
	writeprop "$json" "domainname" '.[].Config.Domainname'
	printf "    restart: %s\n" $(echo "$json" | jq .[].HostConfig.RestartPolicy.Name -r)

	writeprop "$json" "security_opt" '.[].HostConfig.SecurityOpt'
	writeprop "$json" "ulimits" '.[].HostConfig.Ulimits'
	writeprop "$json" "cap_add" '.[].HostConfig.CapAdd'
	writeprop "$json" "cap_drop" '.[].HostConfig.CapDrop'
	writeprop "$json" "cgroup" '.[].HostConfig.Cgroup'
	writeprop "$json" "cgroup_parent" '.[].HostConfig.CgroupParent'
	writeprop "$json" "user" '.[].Config.User'
	writeprop "$json" "working_dir" '.[].Config.WorkingDir'
	writeprop "$json" "ipc" '.[].HostConfig.IpcMode'
	writeprop "$json" "mac_address" '.[].NetworkSettings.MacAddress'
	writeprop "$json" "privileged" '.[].HostConfig.Privileged'
	writeprop "$json" "restart" '.[].HostConfig.RestartPolicy.Name'
	writeprop "$json" "read_only" '.[].HostConfig.ReadonlyRootfs'
	writeprop "$json" "stdin_open" '.[].Config.OpenStdin'
	writeprop "$json" "tty" '.[].Config.Tty'
writeprop "$json" "mac_address" '.[].NetworkSettings.MacAddress'
writeservicenetworks "$json"
# writeserviceexposedports "$json"
writeserviceports "$json"

	writeprop "$json" "dns" '.[].HostConfig.Dns'
	writeprop "$json" "dns_search" '.[].HostConfig.DnsSearch'
	writeprop "$json" "extra_hosts" '.[].HostConfig.ExtraHosts'
	writeservicevolumes "$json"

	writeprop "$json" "environment" '.[].Config.Env'

	if [ ! -z "$labels" ]; then
		printf "    labels:\n"
		printf "%s\n" "$labels"
	fi
}

function writevolumes() {
	local json
	json="$1"
	printf "\nvolumes:\n"
	echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source, .[$key].Destination, .[$key].Mode] | @tsv' -r | sed '/^bind/d' | awk '{ printf "  %s:\n    external: true\n", $2, $4 }'
}

function writenetworks() {
	local json
	json="$1"
	printf "\nnetworks:\n"
	echo "$json" | jq '.[].NetworkSettings.Networks | to_entries[] | [ (.key), (.value | .IPAddress) ] | @tsv ' -r |  awk '{ printf "  %s:\n    external: true\n", $1, $2 }'
}

function writeconfigs() {
	local json
	json="$1"
	printf "\nconfigs: {}\n"
}

json="$(</dev/stdin)"

printf "name: %s\n\n" $(getcontainerlabelvalue "$json" "com.docker.compose.project")

printf "services:\n"
writeservice "$json"
writevolumes "$json"
writenetworks "$json"
writeconfigs "$json"
