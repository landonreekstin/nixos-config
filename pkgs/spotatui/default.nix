# ~/nixos-config/pkgs/spotatui/default.nix
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  openssl,
  alsa-lib,
  dbus,
  pipewire,
}:

rustPlatform.buildRustPackage rec {
  pname = "spotatui";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "LargeModGames";
    repo = "spotatui";
    rev = "v${version}";
    hash = "sha256-6XsKlM4KLwRZk+uJY60a0rKHIEv1ieZPZoBZpRG1sQ0=";
  };

  cargoHash = "sha256-5aj35NGRFb1DiEPU1RGKkvz/wMOIjO1HzkX45GEFbPs=";

  nativeBuildInputs = [
    pkg-config
    llvmPackages.clang
    llvmPackages.libclang
  ];

  buildInputs = [
    openssl
    alsa-lib
    dbus
    pipewire
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  meta = with lib; {
    description = "A Spotify client for the terminal written in Rust, powered by Ratatui";
    homepage = "https://github.com/LargeModGames/spotatui";
    license = licenses.mit;
    mainProgram = "spotatui";
    platforms = platforms.linux;
  };
}
