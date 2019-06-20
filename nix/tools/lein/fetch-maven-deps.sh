#!/usr/bin/env bash

# This script takes care of generating/updating the nix files in this directory.
# For this, we start with a clean cache (in ./.m2~/repository/) and call cljsbuild
#  to cause it to download all the artifacts. At the same time, we note them
#  in lein-project-deps-maven-inputs.txt so that we can use that as an input
#  to maven-inputs2nix.sh

_current_dir=$(cd "${BASH_SOURCE%/*}" && pwd)
_project_file_name='project.clj'
_lein_cmd='lein with-profile prod cljsbuild once'
_repo_path='.m2~'

function filter() {
  sed -E "s;Retrieving ([^ ]+)\.(pom|jar) from $1.*;$2\1;"
}

echo "Computing maven dependencies with \`$_lein_cmd\`..." > /dev/stderr
trap "rm -rf ./${_repo_path}; [ -f ${_project_file_name}.bak ] && mv -f ${_project_file_name}.bak ${_project_file_name}" HUP ERR EXIT INT

cd $_current_dir/../../..

sed -i'.bak' -E "s|(:license \{)|:local-repo \"$_repo_path\" \1|" ${_project_file_name}
rm -rf ./${_repo_path}
$_lein_cmd 2>&1 \
  | grep Retrieving \
  | filter clojars https://repo.clojars.org/ \
  | filter central https://repo1.maven.org/maven2/