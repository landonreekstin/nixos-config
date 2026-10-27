# ~/nixos-config/pkgs/browser-puck/default.nix
# browser-puck: the team air-hockey game server plus its built web client, from its own repo.
# modules/nixos/homelab/browser-puck.nix runs it on mini-server.
# To update: bump `rev`, `hash` and `npmDepsHash` — see docs/companion-repos.md#browser-puck.
{ buildNpmPackage, fetchFromGitHub, nodejs_24, runtimeShell }:

buildNpmPackage {
  pname = "browser-puck";
  version = "unstable-2026-10-27";

  src = fetchFromGitHub {
    owner = "landonreekstin";
    repo = "browser-puck";
    rev = "9b9e3a7d9a2f1b0e91a2388bd28285abca8dae1b";
    hash = "sha256-FHPBUg9BWo7qmOLdsjciYCwY3IXr4E7Q3pfwEnMV6Jw=";
  };
  # Changes whenever the repo's package-lock.json does.
  npmDepsHash = "sha256-89/f8K11vfm75JwNXGaSfEgpTw6/MeXDwaHruicNjcU=";
  nodejs = nodejs_24;

  # `npm run build`: client/dist (static) + server/dist/main.js (one bundled file).
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/browser-puck/node_modules $out/bin
    cp -r client/dist $out/share/browser-puck/client
    cp server/dist/main.js $out/share/browser-puck/server.js
    # The bundle's only runtime dependency.
    cp -r node_modules/ws $out/share/browser-puck/node_modules/
    cat > $out/bin/browser-puck <<SH
    #!${runtimeShell}
    export STATIC_DIR="\''${STATIC_DIR:-$out/share/browser-puck/client}"
    exec ${nodejs_24}/bin/node $out/share/browser-puck/server.js "\$@"
    SH
    chmod +x $out/bin/browser-puck
    runHook postInstall
  '';
}
