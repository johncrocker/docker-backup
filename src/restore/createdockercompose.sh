#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

function getlabels() {
	local json
	json="$1"
	echo "$json" | jq '.[].Config.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk '!/^(org.opencontainers|com.docker)/{printf ("      - \"%s=%s\"\n" ,$1,$2)}' | sort -u
}

function writeprop() {
	local json
	local prop
	local path
	local value
	json="$1"
	prop="$2"
	path="$3"

	value=$(echo "$json" | jq "$path" -r )
	if [[ ! -z "$value" ]]; then
		if [[ ! "$value" = "null" ]] && [[ ! "$value" = "[]" ]]; then
		if [[ "$value" =~ \[.* ]]; then
			value=$(echo "$json" | jq "$path | @tsv" -r )
			printf "    %s:\n" "$prop"
			echo "$value" | tr "\t" "\n" | sed -e 's/^/      - /'
		else
			printf "    %s: %s\n" "$prop" "$value"
		fi
		fi
	fi
}

json="$(</dev/stdin)"
labels=$( getlabels "$json")

printf "services:\n"
printf "  %s:\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
printf "    image: %s\n" $(echo "$json" | jq .[].Config.Image -r)
printf "    container_name: %s\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
printf "    hostname: %s\n" $(echo "$json" | jq .[].Config.Hostname -r)
writeprop "$json" "domainname" '.[].Config.Domainname'
printf "    restart: %s\n" $(echo "$json" | jq .[].HostConfig.RestartPolicy.Name -r)

writeprop "$json" "security_opt" '.[].HostConfig.SecurityOpt'
writeprop "$json" "ulimits" '.[].HostConfig.Ulimits'
writeprop "$json" "cap_drop" '.[].HostConfig.CapDrop'
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

writeprop "$json" "dns" '.[].HostConfig.Dns'
writeprop "$json" "dns_search" '.[].HostConfig.DnsSearch'
writeprop "$json" "environment" '.[].Config.Env'
writeprop "$json" "extra_hosts" '.[].HostConfig.ExtraHosts'


if [ ! -z "$labels" ]; then
printf "    labels:\n"
printf "%s\n" "$labels"
fi

printf "\nvolumes:\n"
printf "  {}\n"

printf "\nnetworks:\n"
printf "  {}\n"
