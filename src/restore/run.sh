
#!/usr/bin/env bash
# shellcheck disable=SC2317 # Don't warn about unreachable commands in this file
# shellcheck disable=SC1090 # Can't follow non-constant source. Use a directive to specify location
# shellcheck disable=SC2002 # Useless cat. Consider cmd < file | .. or cmd file | .. instead.

container="$1"
basedir=$(ls -td -- /media/external/docker-backup/* | head -n 1)
echo  "basedir=$basedir"

if [ -z "$container" ]; then
	container="dbgate"
fi

containerfile="$basedir"/"$container"/"container.json"
networkfile="$basedir"/"$container"/"networks.json"
cp "$containerfile" ./inspect.json
cp "$networkfile" ./network.json
./createdockerrun.sh "$containerfile" "$networkfile"
