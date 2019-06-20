#!/usr/bin/env bash

# This script takes care of generating/updating the nix files in this directory.
# For this, we start with a clean cache (in ./.m2~/repository/) and call cljsbuild
#  to cause it to download all the artifacts. At the same time, we note them
#  in lein-project-deps-maven-inputs.txt so that we can use that as an input
#  to maven-inputs2nix.sh

set -e

_current_dir=$(cd "${BASH_SOURCE%/*}" && pwd)
_inputs_file_path="$_current_dir/lein-project-deps-maven-inputs.txt"
_deps_nix_file_path="$_current_dir/lein-project-deps.nix"
_nix_shell_opts="-I nixpkgs=https://github.com/status-im/nixpkgs/archive/db492b61572251c2866f6b5e6e94e9d70e7d3021.tar.gz"

echo "Regenerating Nix files, this process should take 5-10 minutes"
nix-shell ${_nix_shell_opts} --run "$_current_dir/fetch-maven-deps.sh > $_inputs_file_path" \
          --pure --packages leiningen git
echo "Generating $(basename $_deps_nix_file_path) from $(basename $_inputs_file_path)..."
nix-shell ${_nix_shell_opts} \
          --run "$_current_dir/../maven/maven-inputs2nix.sh $_inputs_file_path > $_deps_nix_file_path" \
          --packages maven
echo "Done"
