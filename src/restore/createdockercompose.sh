#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

function banner() {
	echo "                                                        "
 	echo "                                                        "
	echo "  mmm    mmm   mmmmm  mmmm    mmm    mmm    mmm    m mm "
	echo " #  w	 \"  \"  #\" \"#  # # #  #\" \"#  #\" \"#  #   \"   #\"  #   "
	echo " #      #   #  # # #  #   #  #   #   \"\"\"m  #\"\"\"\"   #    "
	echo " \"#mm\"  \"#m#\"  # # #  ##m#\"  \"#m#\"  \"mmm\"  \"#mm\"   #    "
	echo "                      #                                 "	
	echo ""
}

function getnetwork() {
	local json="$1"
	local net="$2"

	echo "$json" | jq ".[] | select (.Name==\"$net\")"
}

function getlabels() {
	local json
	json="$1"
	echo "$json" | jq '.[].Config.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk '!/^(org.opencontainers|com.docker)/{printf ("      - \"%s=%s\"\n" ,$1,$2)}' | sort -u
}

function getnetworklabelvalue() {
	local json
	local label
	json="$1"
	label="$2"
	echo "$json" | jq '.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk -v label="$label" '$1==label { print $2 }'
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

	echo "$json" | jq '.[].NetworkSettings.Networks | to_entries[] | [ (.key), (.value | .IPAddress) ] | @tsv ' -r | awk '{ printf "      %s:\n        ipv4_address: %s\n", $1, $2 }'
}

function writeserviceexposedports() {
	local json
	json="$1"
	result=$(echo "$json" | jq '.[].Config.ExposedPorts' -r | sed 's/{}/null/g' | sort -u)

	if [ "$result" != "null" ]; then
		printf "    %s:\n" "expose"
		echo "$json" | jq '.[].Config.ExposedPorts | to_entries[] | .key ' -r | awk '{if ($1 ~ /\/tcp$/ ) { printf ("%s\n",$1) } else { printf ("%s/tcp\n",$1) } }' | sort -u | awk '{printf("      - \"%s\"\n", $1)}'
	fi
}

function writeserviceports() {
	local json
	json="$1"
	result=$(echo "$json" | jq '.[].NetworkSettings.Ports' -r | sed 's/{}/null/g')

	if [ "$result" != "null" ]; then
		result=$(echo "$json" | jq '.[].NetworkSettings.Ports | to_entries[] | [ (.key), (.value | .[]?.HostPort ), (.value | .[]?.HostIp ) ] | @tsv' -r | awk '! ( NF==1 )' | awk '{ if ($3=="0.0.0.0") {printf ("      - \"%s:%s\"\n", $2,$1)} else {printf ("      - \"%s:%s:%s\"\n", $3,$2,$1)} }' | sort -u)

		if [ ! -z "$result" ]; then
			printf "    %s:\n" "ports"
			echo "$result"
		fi
	fi
}

function writeservicevolumes() {
	local json
	json="$1"

	printf "    %s:\n" "volumes"

	echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source, .[$key].Destination, .[$key].Mode] | @tsv' -r | sed '/^bind/d' | awk '{if ($5 && $5!="z") {printf "      - %s:%s:%s\n", $2, $4, $5} else {printf "      - %s:%s\n", $2, $4} }'
	echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source,.[$key].Destination,.[$key].Mode] | @tsv' -r | sed '/^volume/d' | awk '{if ($4 && $4!="z") {printf "      - %s:%s:%s\n", $2, $3, $4} else {printf "      - %s:%s\n", $2, $3} }'
}

function getnetworkmode() {
	local json
	local networkjson
	json="$1"
	networkjson="$2"
	netmode=$(echo "$json" | jq '.[].HostConfig.NetworkMode' -r)
	knownnet=$(echo "$networkjson" | jq ".[] | select(.Id==\"$netmode\") | .Id")

	if [ -z "$knownnet" ]; then
		echo "$netmode"
	fi
}

function writenetworkmode() {
	local json
	local networkjson
	json="$1"
	networkjson="$2"
	netmode=$(getnetworkmode "$json" "$networkjson")

	if [ ! -z "$netmode" ]; then
		printf "    network_mode: %s\n" "$netmode"
	fi
}

function writeprop() {
	local json
	local prop
	local path
	local value
	local format
	json="$1"
	prop="$2"
	path="$3"
	format="$4"

	if [ -z "$format" ]; then
		format="default"
	fi

	value=$(echo "$json" | jq "$path" -r)
	if [[ ! -z "$value" ]] && [[ ! "$value" = "null" ]] && [[ ! "$value" = "[]" ]]; then
		if [[ "$value" =~ \[.* ]]; then
			if [ "$format" = "array" ]; then
				value=$(echo "$json" | jq "$path" -r -c)
				printf "    %s: %s\n" "$prop" "$value"
			else
				value=$(echo "$json" | jq "$path | @tsv" -r)
				printf "    %s:\n" "$prop"
				echo "$value" | tr "\t" "\n" | sed -e 's/^/      - /'
			fi
		else
			printf "    %s: %s\n" "$prop" "$value"
		fi
	fi
}

function writeservicedevices() {
	local json
	json="$1"

	result=$(echo "$json" | jq '.[].HostConfig.Devices' -r -c)
	if [ "$result" != "null" ]; then
		result=$(echo "$json" | jq '.[].HostConfig.Devices | to_entries[] | [ (.value) | .PathOnHost, .PathInContainer ] | @tsv' -r | awk '{ printf "      - \"%s:%s\"\n", $1, $2 }')

		if [ ! -z "$result" ]; then
			printf "    %s:\n" "devices"
			echo "$result"
		fi
	fi
}

function writedepends() {
	local json
	json="$1"
	result=$(getcontainerlabelvalue "$json" "com.docker.compose.depends_on")

	if [ ! -z "$result" ]; then
		printf "    depends_on:\n"
		for service in $(echo "$result" | tr "," "\n"); do
			servicename=$(echo "$service" | cut -d ':' -f1)
			condition=$(echo "$service" | cut -d ':' -f2)
			required=$(echo "$service" | cut -d ':' -f3)
			printf "      %s:\n" "$servicename"
			printf "        condition: %s\n" "$condition"
			printf "        required: %s\n" "$required"
		done
	fi
}

function writeextrahosts() {
	local json
	json="$1"
	value=$(echo "$json" | jq '.[].HostConfig.ExtraHosts' -r)

	if [[ ! -z "$value" ]] && [[ ! "$value" = "null" ]] && [[ ! "$value" = "[]" ]]; then
		printf "    extra_hosts:\n"
		echo "$json" | jq '.[].HostConfig.ExtraHosts | @tsv' -r | awk -F : '{printf "      - \"%s=%s\"\n" ,$1,$2}'
	fi
}

function writeservice() {
	local json
	local networkjson
	json="$1"
	networkjson="$2"
	netmode=$(getnetworkmode "$json" "$networkjson")
	labels=$(getlabels "$json")

	printf "  %s:\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
	printf "    image: %s\n" $(echo "$json" | jq .[].Config.Image -r)
	printf "    container_name: %s\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
	printf "    hostname: %s\n" $(echo "$json" | jq .[].Config.Hostname -r)
	writeprop "$json" "domainname" '.[].Config.Domainname'
	printf "    restart: %s\n" $(echo "$json" | jq .[].HostConfig.RestartPolicy.Name -r)
	writedepends "$json"
	env_file=$(getcontainerlabelvalue "$json" "com.docker.compose.project.environment_file")
	if [ ! -z "$env_file" ]; then
		printf "    env_file: %s\n" "$env_file"
	fi

	writeprop "$json" "command" '.[].Config.Cmd' 'array'
	writeprop "$json" "entrypoint" '.[].Config.Entrypoint'

	writeprop "$json" "security_opt" '.[].HostConfig.SecurityOpt'
	writeprop "$json" "ulimits" '.[].HostConfig.Ulimits'
	writeprop "$json" "cap_add" '.[].HostConfig.CapAdd'
	writeprop "$json" "cap_drop" '.[].HostConfig.CapDrop'
	writeprop "$json" "cgroup" '.[].HostConfig.Cgroup'
	writeprop "$json" "cgroup_parent" '.[].HostConfig.CgroupParent'
	writeprop "$json" "user" '.[].Config.User'
	writeprop "$json" "working_dir" '.[].Config.WorkingDir'
	writeprop "$json" "ipc" '.[].HostConfig.IpcMode'
	writeprop "$json" "privileged" '.[].HostConfig.Privileged'
	writeprop "$json" "restart" '.[].HostConfig.RestartPolicy.Name'
	writeprop "$json" "read_only" '.[].HostConfig.ReadonlyRootfs'
	writeprop "$json" "stdin_open" '.[].Config.OpenStdin'
	writeprop "$json" "stop_grace_period" '.[].Config.StopTyyimeout'
	writeprop "$json" "tty" '.[].Config.Tty'
	writeprop "$json" "mac_address" '.[].NetworkSettings.MacAddress'

	writenetworkmode "$json" "$networkjson"

	writeservicedevices "$json"
	if [ -z "$netmode" ]; then
		writeservicenetworks "$json"
	fi

	writeserviceexposedports "$json"
	writeserviceports "$json"

	writeprop "$json" "dns" '.[].HostConfig.Dns'
	writeprop "$json" "dns_search" '.[].HostConfig.DnsSearch'
	writeextrahosts "$json"
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
	result=$(echo "$json" | jq '.[].Mounts | keys[] as $key | [.[$key].Type, .[$key].Name,.[$key].Source, .[$key].Destination, .[$key].Mode] | @tsv' -r | sed '/^bind/d' | awk '{ printf "  %s:\n    external: true\n    name: %s\n", $2, $2 }')

	if [ ! -z "$result" ]; then
		printf "\nvolumes:\n"
		echo "$result"
	fi
}

function writenetworks() {
	local json
	local networkjson
	json="$1"
	networkjson="$2"
	netmode=$(getnetworkmode "$json" "$networkjson")

	if [ ! -z "$netmode" ]; then
		return
	fi

	result=$(echo "$json" | jq '.[].NetworkSettings.Networks | to_entries[] | [ (.key), (.value | .IPAddress) ] | @tsv ' -r | awk '{ printf "%s\n",$1 }')

	if [ ! -z "$result" ]; then
		printf "\nnetworks:\n"
		for network in $(echo "$json" | jq '.[].NetworkSettings.Networks | to_entries[] | [ (.key), (.value | .IPAddress) ] | @tsv ' -r | awk '{ printf "%s\n",$1 }'); do
			netjson=$(getnetwork "$networkjson" "$network")
			internal=$(getnetworklabelvalue "$netjson" "com.docker.compose.network")
			printf "  %s:\n" "$network"
			printf "    name: %s\n" "$network"

			if [ "$internal" != "internal" ]; then
				printf "    external: true\n"
			else
				printf "    external: false\n"
				writenetworksettings "$netjson"

			fi
		done
	fi

}

function writenetworksettings() {
	local json
	json="$1"
	printf "    ipam:\n"
	printf "      driver: %s\n" $(echo "$json" | jq .Driver)
	printf "      config:\n"
	echo "$json" | jq '.IPAM.Config[] | to_entries[] | [ (.key),(.value)] | @tsv' -r | awk '{ printf "        %s: %s\n",tolower($1),$2 }'
}

json=$(cat "$1")
networkjson=$(cat "$2")

banner 1>&2

printf "name: %s\n\n" $(getcontainerlabelvalue "$json" "com.docker.compose.project")

printf "services:\n"
writeservice "$json" "$networkjson"
writevolumes "$json"
writenetworks "$json" "$networkjson"
