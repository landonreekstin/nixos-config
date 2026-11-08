# ~/nixos-config/pkgs/hypr-overview/default.nix
# hypr-overview: the Super+Tab window overview for Hyprland, a Quickshell (QML)
# config. The source lives in its own repo, github:landonreekstin/hypr-overview
# (docs/companion-repos.md); hyprland/functional.nix starts the daemon and binds
# the keys.
#
#   hypr-overview          the daemon (hidden until asked)
#   hypr-overview-ipc FN   open | prev | toggle | commit | close | state
#
# `srcOverride` builds from a local checkout instead of the pin. (Not `src`:
# callPackage would fill that from pkgs.src, an alias that throws.)
{ lib, stdenvNoCC, fetchFromGitHub, writeShellScriptBin, symlinkJoin, quickshell, srcOverride ? null }:

let
  rev = "81a1b53f2b01c30feb766c75a425f68913f27f28";

  share = stdenvNoCC.mkDerivation {
    pname = "hypr-overview-qml";
    version = "0-unstable-2026-11-07";

    src = if srcOverride != null then srcOverride else fetchFromGitHub {
      owner = "landonreekstin";
      repo = "hypr-overview";
      inherit rev;
      hash = "sha256-PhNKF+5EwB46Px8YcxnQP6ZVyr7TbAB30qyhDaJCtUI=";
    };

    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/hypr-overview
      cp *.qml $out/share/hypr-overview/
      runHook postInstall
    '';
  };

  dir = "${share}/share/hypr-overview";
in
symlinkJoin {
  name = "hypr-overview";
  paths = [
    (writeShellScriptBin "hypr-overview" ''exec ${quickshell}/bin/qs -p ${dir} "$@"'')
    (writeShellScriptBin "hypr-overview-ipc" ''exec ${quickshell}/bin/qs -p ${dir} ipc call overview "$@"'')
  ];
  meta = {
    description = "Windows-style Super+Tab window overview for Hyprland";
    homepage = "https://github.com/landonreekstin/hypr-overview";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
