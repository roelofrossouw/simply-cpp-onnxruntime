#!/bin/bash
#~~~~~~~~~~
# Syncs this repo to a build server and runs scripts/publish.sh there. The
# packaged binary isn't Ubuntu-release-specific, so any one build server
# publishes it to jammy/noble/resolute alike - no need to run this three
# times against three servers the way the compiled sc-* modules do.
#
# Usage: scripts/deploy.sh [server] [user]

module="sc-onnxruntime"
server="${1:-build-noble}"
user="${2:-root}"
scriptfile=$(realpath "$0")
scriptpath="${scriptfile%/*}"
dirpath=$(realpath "$scriptpath"/..)
pushd "$dirpath" || exit
echo "Syncing $dirpath to $server:$module"
rsync -av ./ "$user@$server:/var/www/build/$module/" --exclude=".git" --exclude=".idea" --exclude="work" --exclude="pkg" --delete || exit
ssh "$user@$server" "cd /var/www/build/$module && bash scripts/publish.sh"
remote_result=$?
popd || exit
exit $remote_result
