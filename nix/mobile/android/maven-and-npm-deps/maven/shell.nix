{ config ? { android_sdk.accept_license = true; },
  pkgs ? import ((import <nixpkgs> { }).fetchFromGitHub {
    owner = "status-im";
    repo = "nixpkgs";
    rev = "db492b61572251c2866f6b5e6e94e9d70e7d3021";
    sha256 = "188r7gbcrxi20nj6xh9bmdf3lbjwb94v9s0wpacl7q39g1fca66h";
    name = "nixpkgs-source";
  }) { inherit config; } }:
with pkgs;

let
  inherit (callPackage ../../android-env.nix { }) androidComposition licensedAndroidEnv;

in mkShell {
  buildInputs = [
    curl
    gradle_4_10
    git
    maven
  ];
  shellHook = ''
    export ANDROID_HOME=${licensedAndroidEnv}
    # TODO: Add real sttaus-go dependency
    export STATUS_GO_ANDROID_LIBDIR=/nix/store/iwmjl1wc90c5s7316nflzx9bp08vkg6q-status-go-v0.25.0-beta.1-android/lib
  '';
}
