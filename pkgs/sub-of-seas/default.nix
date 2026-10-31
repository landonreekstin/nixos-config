# ~/nixos-config/pkgs/sub-of-seas/default.nix
#
# Sub of Seas: lando's co-op WWII submarine game (Godot 4.7, github.com/landonreekstin/sub-of-seas).
# Built from the pin below into one Godot pack (.pck, just the project's files), which needs
# no export templates, only the same Godot to run it on. `godot` is passed in by
# modules/nixos/programs/sub-of-seas.nix so the pack is exported and run on one engine:
# host and players must match, which the game checks when someone joins.
#
# The pin is bumped like any of lando's repos — see docs/companion-repos.md.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  godot,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sub-of-seas";
  version = "0-unstable-2026-10-31";

  src = fetchFromGitHub {
    owner = "landonreekstin";
    repo = "sub-of-seas";
    rev = "b15b6ee930a7f89b7ea9194af09d01a32d2ffd49";
    hash = "sha256-8R5kd/KykJ0bABCkqqRu55ErEtqck3zXtWVh4I//X+0=";
  };

  nativeBuildInputs = [ godot makeWrapper ];

  buildPhase = ''
    runHook preBuild
    # Godot writes its editor settings and import cache under these
    export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR/config XDG_DATA_HOME=$TMPDIR/data XDG_CACHE_HOME=$TMPDIR/cache
    # the build name the game shows (and compares on join), as tools/publish.sh writes it
    echo ${lib.substring 0 7 src.rev} > build.txt
    godot --headless --path . --import
    mkdir -p build
    godot --headless --path . --export-pack "Linux pack" build/sub-of-seas.pck
    test -s build/sub-of-seas.pck
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 build/sub-of-seas.pck $out/share/sub-of-seas/sub-of-seas.pck
    makeWrapper ${lib.getExe godot} $out/bin/sub-of-seas \
      --add-flags "--main-pack $out/share/sub-of-seas/sub-of-seas.pck"
    runHook postInstall
  '';

  meta = {
    description = "Co-op WWII submarine game";
    homepage = "https://github.com/landonreekstin/sub-of-seas";
    mainProgram = "sub-of-seas";
    platforms = [ "x86_64-linux" ];
  };
}
