# ~/nixos-config/pkgs/worldmonitor/default.nix
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "worldmonitor";
  version = "2.5.23";

  src = fetchurl {
    url = "https://github.com/koala73/worldmonitor/releases/download/v${version}/World.Monitor_${version}_amd64.AppImage";
    hash = "sha256-QEuPgOX1D0m08upP544NLCv5jXLnrHcCRT1TJIHKNY0=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The upstream strips bundled GPU/Wayland libs from the AppImage to fix
  # black screens on non-Ubuntu distros, so we need to supply them via the host.
  extraPkgs =
    pkgs: with pkgs; [
      webkitgtk_4_1
      glib-networking
      openssl
    ];

  extraInstallCommands = ''
    install -Dm644 "${appimageContents}/World Monitor.desktop" \
      $out/share/applications/world-monitor.desktop
    sed -i 's|Exec=world-monitor|Exec=worldmonitor|' \
      $out/share/applications/world-monitor.desktop
    find ${appimageContents} -name "*.png" -path "*/icons/*" \
      -exec cp --parents {} $out/share/ \; 2>/dev/null || true
  '';

  meta = {
    description = "Real-time global intelligence dashboard with AI-powered news synthesis";
    longDescription = ''
      World Monitor aggregates news from 435+ feeds across 15 categories and
      synthesizes them using AI. Features dual mapping engines, geopolitical risk
      scoring, financial market tracking, and cross-stream signal correlation.
    '';
    homepage = "https://github.com/koala73/worldmonitor";
    license = lib.licenses.agpl3Only;
    mainProgram = "worldmonitor";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
