{ config ? { android_sdk.accept_license = true; },
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "status-im";
    repo = "nixpkgs";
    rev = "db492b61572251c2866f6b5e6e94e9d70e7d3021";
    sha256 = "188r7gbcrxi20nj6xh9bmdf3lbjwb94v9s0wpacl7q39g1fca66h";
    name = "nixpkgs-source";
  }) { inherit config; } }:

let
  inherit (pkgs.callPackage ../../android-env.nix { }) androidComposition licensedAndroidEnv;
  nodejs = pkgs.nodejs-10_x;
  nodeProjectName = "StatusIm";
  projectNodePackage = import ../../../node2nix/StatusIm { inherit pkgs nodejs; };
  projectNodePackage' = projectNodePackage.package.override(oldAttrs: (realmOverrides oldAttrs) // {
    # Ensure that a package.json is present where node2nix's node-env.nix expects it, instead of the package.json.orig
    postPatch = ''
      outputPackage="$out/lib/node_modules/${nodeProjectName}/package.json"
      mkdir -p $(dirname $outputPackage)
      cp $src/package.json.orig $outputPackage
      chmod +w $outputPackage
      unset outputPackage
    '';
  });
  realmOverrides = import ../../../realm-overrides { inherit nodeProjectName nodejs; inherit (pkgs) stdenv fetchurl; target-os = "android"; };

# TODO: replace this file with a target on the real Nix file infrastructure, to avoid import duplication
in pkgs.mkShell {
  buildInputs = with pkgs; [
    curl
    gradle_4_10
    git
    maven
    projectNodePackage'
  ];
  shellHook = ''
    export ANDROID_HOME=${licensedAndroidEnv}
    # TODO: Add real status-go dependency
    export STATUS_GO_ANDROID_LIBDIR=/nix/store/iwmjl1wc90c5s7316nflzx9bp08vkg6q-status-go-v0.25.0-beta.1-android/lib

    if [ -d ./node_modules ]; then
      chmod -R u+w ./node_modules
      rm -rf ./node_modules
    fi

    cp -R ${projectNodePackage'}/lib/node_modules/`ls ${projectNodePackage'}/lib/node_modules`/node_modules . || exit
    chmod -R u+w ./node_modules/react-native
  '';
}
