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

  patches = [
    # SearchVimm looks the requested platform up in the Vimm registry and, on a
    # miss, simply does not set ?system= - so asking for a platform Vimm does
    # not carry (PC, most obviously: Vimm is console-only) searches every
    # console unfiltered instead of skipping the source, and returns ROMs
    # stamped "Unknown". SearchMyrient already guards exactly this way; this
    # makes Vimm match it. Still present on upstream main as of this pin.
    ./vimm-skip-unsupported-platform.patch

    # Category 4050 is PC/Games in the Newznab tree, and Prowlarr reports it as
    # exactly that. Upstream maps it to Switch instead, to accommodate Nyaa,
    # which uses 4050 for Switch content. That choice costs every standard
    # indexer: the PC category set is used to post-filter results, 4050 was not
    # in it, so genuine PC releases were all discarded while the dead 4000-
    # tagged ones came through - a PC search returned nothing worth having.
    # None of this host's indexers are Nyaa, so the standard meaning is the
    # right one here.
    #
    # Upstream's own tests assert the Switch mapping, so this patch contradicts
    # them. They do not run: doCheck is on, but subPackages restricts the check
    # phase to cmd/gamarr, which has no tests. Dropping subPackages would start
    # running internal/platform's tests and they would fail on this patch.
    ./pc-games-category-4050.patch
  ];

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
