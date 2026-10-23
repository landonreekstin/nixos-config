# ~/nixos-config/pkgs/xbox360-dashboard/default.nix
# The Xbox 360 "Blades" dashboard program: its Quickshell shell (QML), the blade
# shader source, and the Python helpers (controller daemon, games library,
# Jellyfin player, audio switcher). The source lives in its own repo,
# github:landonreekstin/xbox360-dashboard (docs/companion-repos.md); the
# hyprland xbox360 desktop (themes/xbox360/session.nix) adds everything
# host-specific: the generated Config.js, the shader's substituted knots
# compiled to blade.frag.qsb, and each helper's JSON config.
#
# `srcOverride` lets customConfig.homeManager.themes.xbox360.devSource build from a
# local checkout instead of the pin. (Not `src`: callPackage would fill that from
# pkgs.src, an alias that throws.)
{ lib, stdenvNoCC, fetchFromGitHub, python3, srcOverride ? null }:

let
  rev = "508d6e2f25a8390a449191b96d15b0067ca5b973";
  padPython = python3.withPackages (ps: [ ps.evdev ]);
in
stdenvNoCC.mkDerivation {
  pname = "xbox360-dashboard";
  version = "0-unstable-2026-10-23";

  src = if srcOverride != null then srcOverride else fetchFromGitHub {
    owner = "landonreekstin";
    repo = "xbox360-dashboard";
    inherit rev;
    hash = "sha256-zCCkPJNP43yEFlC02GoV3K37reYhEzesVnM7bFZNVlM=";
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
    platforms = lib.platforms.linux;
  };
}
