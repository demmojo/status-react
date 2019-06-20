#!/usr/bin/env bash

#
# This script takes care of generating/updating the default.nix file
# representing the offline Maven repo containing the dependencies
# required to build the project
#

set -e

GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)
current_dir=$(cd "${BASH_SOURCE%/*}" && pwd)
inputs_file_path="$current_dir/maven-inputs.txt"
inputs2nix=$(realpath --relative-to="$current_dir" $GIT_ROOT/nix/tools/maven/maven-inputs2nix.sh)

echo "Regenerating Nix files, this process should take about 90 minutes"
nix-shell --run "$current_dir/fetch-maven-deps.sh | sort -u > $inputs_file_path" \
          --pure $current_dir/shell.nix

pushd $current_dir
$inputs2nix $inputs_file_path > default.nix
echo "Done"
popd