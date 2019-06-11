#!/usr/bin/env bash

# This script takes care of generating/updating the nix files in the directories below

set -e

GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)
_current_dir=$(cd "${BASH_SOURCE%/*}" && pwd)
inputs2nix=$(realpath --relative-to="$_current_dir" $GIT_ROOT/nix/tools/maven/maven-inputs2nix.sh)

pushd $_current_dir
for f in `find . -name maven-inputs.txt`; do
  dir=$(dirname $f)
  echo "Generating $dir/default.nix from $f..."
  $inputs2nix $f > $dir/default.nix
done
echo "Done"
popd