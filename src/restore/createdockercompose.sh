#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

json="$(</dev/stdin)"

printf "services:\n"
printf "  %s:\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
printf "    image: %s\n" $(echo "$json" | jq .[].Config.Image -r)
printf "    container_name: %s\n" $(echo "$json" | jq .[].Name -r | cut -b2-)
printf "    hostname: %s\n" $(echo "$json" | jq .[].Config.Hostname -r)
printf "    restart: %s\n" $(echo "$json" | jq .[].HostConfig.RestartPolicy.Name -r)
printf "    labels:\n"
echo "$json" | jq '.[].Config.Labels | keys[] as $key | [$key,.[$key]] | @tsv' -r | awk '!/^(org.opencontainers|com.docker)/{printf ("      - \"%s=%s\"\n" ,$1,$2)}'

printf "\nvolumes:\n"
printf "  {}\n"

printf "\nnetworks:\n"
printf "  {}\n"
