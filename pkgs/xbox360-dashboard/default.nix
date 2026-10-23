# ~/nixos-config/pkgs/xbox360-dashboard/default.nix
# The Xbox 360 "Blades" dashboard program: its Quickshell shell (QML), the blade
# shader source, and the Python helpers (controller daemon, games library,
# Jellyfin player, audio switcher). The source lives in its own repo,
# github:landonreekstin/xbox360-dashboard (docs/companion-repos.md); the
# hyprland xbox360 desktop (hyprland/desktops/xbox360/session.nix) adds everything
# host-specific: the generated Config.js, the shader's substituted knots
# compiled to blade.frag.qsb, and each helper's JSON config.
#
# `srcOverride` lets customConfig.homeManager.themes.xbox360.devSource build from a
# local checkout instead of the pin. (Not `src`: callPackage would fill that from
# pkgs.src, an alias that throws.)
{ lib, stdenvNoCC, fetchFromGitHub, python3, srcOverride ? null }:

let
  rev = "db14b907a43a5c176aff617ea6891b20b8bdc6c5";
  padPython = python3.withPackages (ps: [ ps.evdev ]);
in
stdenvNoCC.mkDerivation {
  pname = "xbox360-dashboard";
  version = "0-unstable-2026-10-23";

  src = if srcOverride != null then srcOverride else fetchFromGitHub {
    owner = "landonreekstin";
    repo = "xbox360-dashboard";
    inherit rev;
    hash = "sha256-YzTqWl53A7eVP6FW/2wnmLZ1IlBRTRq2nScnYHpOU84=";
  };

  dontConfigure = true;
  dontBuild = true;

  # The helpers are plain scripts with no shebang of their own: which python
  # runs them is the packager's choice (the pad needs evdev, the rest only the
  # standard library).
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/xbox360-dashboard $out/bin
    cp -r shell shaders $out/share/xbox360-dashboard/
    for s in games jellyfin-play audio; do
      { echo "#!${python3}/bin/python3"; cat pad/xbox360-$s.py; } > $out/bin/xbox360-$s
    done
    { echo "#!${padPython}/bin/python3"; cat pad/xbox360-pad.py; } > $out/bin/xbox360-pad
    chmod +x $out/bin/*
    runHook postInstall
  '';

  meta = {
    description = "Xbox 360 Blades dashboard as a Quickshell shell for Hyprland";
    homepage = "https://github.com/landonreekstin/xbox360-dashboard";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
