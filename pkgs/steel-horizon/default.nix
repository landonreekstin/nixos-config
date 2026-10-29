# ~/nixos-config/pkgs/steel-horizon/default.nix
#
# Steel Horizon RTS: a native real-time naval battle game (C11, SDL2, GL 3.3) built
# around the battle layer of Steel Horizon (PSP, 2007), from our steel-horizon-recomp
# repo.
#
# The game data is NOT in here. The `steel-horizon` launcher
# (modules/nixos/programs/steel-horizon.nix) downloads the ISO on first run and turns it
# into the engine's asset folder with the Python tools installed under
# share/steel-horizon (they keep the repo layout: data2json.py reads
# ../evidence/ship_loadouts.json next to itself).
#
# Online players must run the same build (lockstep: a different one desyncs), so hosts
# that play together should be on the same pin. Bumping it: see docs/companion-repos.md.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  SDL2,
  libGL,
}:

stdenv.mkDerivation {
  pname = "steel-horizon";
  version = "0-unstable-2026-10-28";

  src = fetchFromGitHub {
    owner = "landonreekstin";
    repo = "steel-horizon-recomp";
    rev = "0ee3b71e6a28b8864cfdb0de3b56d5edfa5bb747";
    hash = "sha256-tt55inbg4x4ylDY+nvsGeqfBvUbCRz5JhdRfiHpmwxw=";
  };

  nativeBuildInputs = [ cmake ninja pkg-config ];
  buildInputs = [ SDL2 libGL ];

  # The CMake project is engine/; the build dir stays at the repo root (build/).
  cmakeDir = "../engine";

  installPhase = ''
    runHook preInstall
    cd ..
    # shrts finds its standalone data at <binary dir>/../data/standalone.json.
    install -Dm755 build/shrts $out/libexec/steel-horizon/bin/shrts
    install -Dm644 engine/data/standalone.json $out/libexec/steel-horizon/data/standalone.json
    install -Dm644 -t $out/share/steel-horizon/tools \
      tools/imp_extract.py tools/data2json.py tools/at3wav.py
    install -Dm644 -t $out/share/steel-horizon/evidence evidence/ship_loadouts.json
    install -Dm644 -t $out/share/doc/steel-horizon README.md
    runHook postInstall
  '';

  meta = {
    description = "Native real-time naval battle game built around Steel Horizon's battle layer";
    homepage = "https://github.com/landonreekstin/steel-horizon-recomp";
    platforms = [ "x86_64-linux" ];
    mainProgram = "shrts";
  };
}
