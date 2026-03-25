# ~/nixos-config/pkgs/tuisic/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  git,
  curl,
  fmt,
  ftxui,
  mpv-unwrapped,
  rapidjson,
  sdbus-cpp_2,
}:

stdenv.mkDerivation rec {
  pname = "tuisic";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "Dark-Kernel";
    repo = "tuisic";
    rev = "v${version}";
    hash = "sha256-JQovP7CEmbeamag3vcsXUchFFEizoebSVmC2VXO0tg8=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    git
  ];

  buildInputs = [
    curl
    fmt
    ftxui
    mpv-unwrapped
    rapidjson
    sdbus-cpp_2
  ];

  cmakeFlags = [
    "-DWITH_CAVA=OFF"
    "-DWITH_DISCORD=OFF"
    "-DWITH_MPRIS=ON"
    # Prevent CMake from trying to download ftxui via FetchContent
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
  ];

  meta = with lib; {
    description = "A simple TUI online music streaming application written in C++ with vim motions";
    homepage = "https://github.com/Dark-Kernel/tuisic";
    license = licenses.gpl3Only;
    mainProgram = "tuisic";
    platforms = platforms.linux;
  };
}
