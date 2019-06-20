{ stdenv, stdenvNoCC, lib, target-os, callPackage,
  mkFilter, bash, git, gradle, gradleOpts ? "", androidEnvShellHook, mavenAndNpmDeps, nodejs, openjdk, prod-build, status-go, zlib, strace }:

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
            #"android/app/src/release"
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
  buildInputs = [ bash git gradle nodejs openjdk strace ] ++ status-go.buildInputs-android;
  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  buildPhase =
    androidEnvShellHook +
    status-go.shellHook-android + ''
    export HOME=$NIX_BUILD_TOP
    export STATUS_REACT_HOME=$PWD
    export PATH=$STATUS_REACT_HOME/node_modules/.bin:$PATH
    export REACT_NATIVE_DEPENDENCIES="${mavenAndNpmDeps.react-native-deps}/deps"

    cp -a --no-preserve=ownership ${mavenAndNpmDeps.deps}/.gradle $HOME
    chmod -R u+w $HOME/.gradle
    cp -a --no-preserve=ownership ${prod-build}/index*.js .

    # TODO: fix versionCode in android/app/build.gradle which has been hardcoded to 9999 by mavenAndNpmDeps
    # mv android/app/build.gradle android/app/build.gradle~
    cp -a --no-preserve=ownership ${mavenAndNpmDeps.deps}/project/android/ .
    chmod u+w android/app
    chmod -R u+w android/.gradle
    # mv android/app/build.gradle~ android/app/build.gradle
    
    ln -sf mobile_files/package.json.orig package.json
    ln -sf mobile_files/metro.config.js metro.config.js

    substituteInPlace android/gradle.properties \
      --replace 'org.gradle.jvmargs=' 'org.gradle.daemon=false
org.gradle.jvmargs='
    patchShebangs scripts
    scripts/generate-keystore.sh

    #ln -sf ${mavenAndNpmDeps.deps}/project/node_modules/

    cp -a --no-preserve=ownership ${mavenAndNpmDeps.deps}/project/node_modules/ .
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

    # OPTIONAL: There's no need to forward debug ports for a release build, just disable it
    substituteInPlace node_modules/realm/android/build.gradle \
      --replace 'compileTask.dependsOn forwardDebugPort' 'compileTask'
    substituteInPlace android/gradlew \
      --replace 'gradle --no-build-cache' 'gradle --stacktrace -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --offline --no-build-cache --no-daemon ${gradleOpts}'

    # mkdir -p /build/.gradle/wrapper/dists/gradle-4.10.2-bin/cghg6c4gf4vkiutgsab8yrnwv/gradle-4.10.2
    # cp -R ${gradle}/bin ${gradle}/lib/gradle/lib /build/.gradle/wrapper/dists/gradle-4.10.2-bin/cghg6c4gf4vkiutgsab8yrnwv/gradle-4.10.2

    # STATUS_REACT_HOME=$PWD nix/mobile/reset-node_modules.sh "${mavenAndNpmDeps.deps}/project"
    # STATUS_REACT_HOME=$PWD nix/mobile/android/fix-node_modules-permissions.sh

    pushd android
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib.makeLibraryPath [ zlib ]} \
      gradle --stacktrace assembleRelease -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --offline --no-build-cache --no-daemon ${gradleOpts} || exit
      #strace -e trace=creat,open,openat,fstat,lstat,stat -f gradle -info --stacktrace assembleRelease -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --no-build-cache --no-daemon ${gradleOpts} || exit
      #strace -s 2000 -vv -r -f gradle --stacktrace assembleRelease -Dmaven.repo.local='${mavenAndNpmDeps.deps}/.m2/repository' --offline --no-daemon ${gradleOpts} || exit
    popd > /dev/null
  '';
  installPhase = ''
    mkdir -p $out
    cp android/app/build/outputs/apk/release/app-release.apk $out/app-release.apk
  '';
}
