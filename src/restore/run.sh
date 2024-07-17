#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

container="$1"

if [ -z "$container" ]; then
	container="photoprism"
fi

docker container inspect "$container" > ./inspect.json

cat ./inspect.json | ./createdockercompose.sh
