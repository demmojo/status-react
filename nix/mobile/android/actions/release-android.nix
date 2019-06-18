{ stdenv, stdenvNoCC, lib, target-os, callPackage,
  mkFilter, bash, git, gradle, gradleOpts ? "", androidEnvShellHook, mavenAndNpmDeps, nodejs, openjdk, prod-build, status-go, zlib }:

let
  name = "release-${target-os}";

in stdenv.mkDerivation {
  inherit name;
  src =
    let path = ./../../../..;
    in builtins.path { # We use builtins.path so that we can name the resulting derivation, otherwise the name would be taken from the checkout directory, which is outside of our control
      inherit path;
      name = "status-react-${name}";
      filter =
        mkFilter {
          dirRootsToInclude = [ 
            #"android/app"
            "mobile_files"
            "scripts"
            "modules/react-native-status"
            "packager"
            "resources"
          ];
          dirsToExclude = [ ".git" ".svn" "CVS" ".hg" ".gradle" "build" "intermediates" "libs" "obj" ];
          filesToInclude = [ ".env" "STATUS_GO_VERSION" "VERSION" ];
          root = path;
        };
    };
  buildInputs = [ bash git gradle nodejs openjdk ] ++ status-go.buildInputs-android;
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  buildPhase =
    androidEnvShellHook +
    status-go.shellHook-android + ''
    cp ${prod-build}/index*.js .

    # TODO: fix versionCode in android/app/build.gradle which has been hardcoded to 9999 by mavenAndNpmDeps
    # mv android/app/build.gradle android/app/build.gradle~
    cp -Rf ${mavenAndNpmDeps.deps}/android/ .
    chmod -R u+w android/
    # mv android/app/build.gradle~ android/app/build.gradle
    
    ln -sf mobile_files/package.json.orig package.json
    ln -sf mobile_files/metro.config.js metro.config.js

    substituteInPlace android/gradle.properties \
      --replace 'STATUS_RELEASE_STORE_FILE=~/.gradle/status-im.keystore' 'STATUS_RELEASE_STORE_FILE=.gradle/status-im.keystore'
    patchShebangs scripts
    scripts/generate-keystore.sh

    #ln -sf ${mavenAndNpmDeps.deps}/node_modules/

    cp -R ${mavenAndNpmDeps.deps}/node_modules/ .
    chmod -R u+w node_modules/react-native/
    chmod -R u+w node_modules/react-native-webview/
    rm node_modules/react-native-webview/android/local.properties
    chmod -R u-w node_modules/react-native-webview/
    for d in `ls node_modules/react-native-*/android/build -d1`; do
      chmod -R u+w $d
    done
    for d in `ls node_modules/react-native-*/android -d1`; do
      chmod u+w $d
    done
    chmod u+w node_modules/realm/android

    # STATUS_REACT_HOME=$PWD nix/mobile/reset-node_modules.sh "${mavenAndNpmDeps.deps}"
    # STATUS_REACT_HOME=$PWD nix/mobile/android/fix-node_modules-permissions.sh

    pushd android
    #gradle build -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --offline --no-build-cache --no-daemon ${gradleOpts} || exit
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib.makeLibraryPath [ zlib ]} \
      gradle --info --stacktrace assembleRelease -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --offline --no-build-cache --no-daemon ${gradleOpts} || exit
    popd > /dev/null
  '';
  installPhase = ''
    mkdir -p $out
    cp android/app/build/outputs/apk/release/app-release.apk $out/app-release.apk
  '';
}
