# ~/nixos-config/pkgs/gamarr/default.nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "gamarr";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "JeremiahM37";
    repo = "gamarr";
    rev = "v${version}";
    hash = "sha256-TB8mITLbYUikmm46BnZ30irefRmf2JFxlBpufuGYuJg=";
  };

  vendorHash = "sha256-sA5RFv+etkOABkCR6FGkjTq/AEXDD0eHiiEbcu9CSCk=";

  subPackages = [ "cmd/gamarr" ];

  # Pure-Go SQLite (modernc.org/sqlite), so the binary is static and needs no
  # C toolchain. Upstream builds it the same way.
  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  # The frontend is committed already built under web/static and pulled into the
  # binary by web/embed.go, so there is no npm step here. Upstream's Dockerfile
  # runs a Vite build, but that only matters on main, where the UI was rewritten
  # in React; at v1.3.0 web/static holds the vanilla JS and vendored Tailwind
  # that index.html actually references.

  meta = with lib; {
    description = "Self-hosted game and ROM search, download, and library manager";
    homepage = "https://github.com/JeremiahM37/gamarr";
    license = licenses.mit;
    mainProgram = "gamarr";
    platforms = platforms.linux;
  };
}
