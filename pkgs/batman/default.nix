# ~/nixos-config/pkgs/batman/default.nix
#
# The Batman (JAKKS Pacific TV game) as a native Linux program, from our
# jakks-batman-recomp repo: a µ'nSP interpreter plus the console's hardware, frame-exact
# with MAME, with local and online co-op (Batman + Robin).
#
# The game data is NOT in here: the ROM is downloaded by the `batman` launcher
# (modules/nixos/programs/batman.nix) on first run, and Robin's sprites are generated
# from it then, by the generators installed under share/batman.
#
# Online players must run the same build (the host refuses a different one), so every
# host that plays together should be on the same pin. Bumping it: see
# docs/companion-repos.md.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  SDL2,
}:

stdenv.mkDerivation {
  pname = "batman";
  version = "0-unstable-2026-10-18";

  src = fetchFromGitHub {
    owner = "landonreekstin";
    repo = "jakks-batman-recomp";
    rev = "d8311639dda723265325b23320efd48b1a8865f1";
    hash = "sha256-hvoYcHh0j1v21nvkTORbKK9MSNXYM0uFSYb/IkaB3xw=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ SDL2 ];

  # Only the two programs: the Makefile's other targets (Robin's mod.txt) need the ROM.
  buildPhase = ''
    runHook preBuild
    make -C recomp -j$NIX_BUILD_CORES build/batman build/batman-rt
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 recomp/build/batman $out/libexec/batman/batman
    install -Dm755 recomp/build/batman-rt $out/libexec/batman/batman-rt
    # Robin's sprite generators keep their layout: robin-p2 imports ../robin, which imports
    # ../../tools.
    for m in robin robin-p2; do
      install -Dm644 mods/$m/generate.py $out/share/batman/mods/$m/generate.py
    done
    install -Dm644 -t $out/share/batman/tools tools/sprites.py tools/gfx.py
    install -Dm644 -t $out/share/doc/batman README.md
    runHook postInstall
  '';

  meta = {
    description = "Native runtime for the JAKKS Pacific The Batman TV game, with online co-op";
    homepage = "https://github.com/landonreekstin/jakks-batman-recomp";
    platforms = [ "x86_64-linux" ];
  };
}
