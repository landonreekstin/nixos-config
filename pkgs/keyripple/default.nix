# ~/nixos-config/pkgs/keyripple/default.nix
#
# Key Ripple: insideabush's soft gold key-press ripple for his G915, painted through the
# OpenRGB server. One Python file (evdev + openrgb-python).
# Source: github.com/cblaney00/keyripple (his vibe project ~/projects/keyripple). The
# service that runs it is in hosts/blaney-pc/hardware.nix. Bumping the pin:
# docs/companion-repos.md.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  localSrc ? null,
  python3,
}:

let
  python = python3.withPackages (p: [ p.evdev p.openrgb-python ]);
in
stdenvNoCC.mkDerivation {
  pname = "keyripple";
  # The pin is his latest *release*. A host in vibeProjects.localApps passes his project
  # folder as localSrc instead (pkgs/vibe-local-src.nix), so it runs his newest work.
  version = if localSrc != null then "0-local" else "0-unstable-2026-11-12";

  src = if localSrc != null then localSrc else fetchFromGitHub {
    owner = "cblaney00";
    repo = "keyripple";
    rev = "1473af0a712ec32279c4606e253cbc16841691f5";
    hash = "sha256-ZWWUFTrqYfJjrTO0DRfjy8P7HPPkA8SnV4cZcJBtOG8=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 keyripple.py $out/share/keyripple/keyripple.py
    mkdir -p $out/bin
    cat > $out/bin/keyripple <<EOF
    #!${stdenvNoCC.shell}
    exec ${python}/bin/python3 -I $out/share/keyripple/keyripple.py "\$@"
    EOF
    chmod +x $out/bin/keyripple
    runHook postInstall
  '';

  meta = {
    description = "Soft gold key-press ripple on a Logitech G915, via OpenRGB";
    homepage = "https://github.com/cblaney00/keyripple";
    mainProgram = "keyripple";
    platforms = lib.platforms.linux;
  };
}
