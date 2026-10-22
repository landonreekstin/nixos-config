# ~/nixos-config/pkgs/xbox360-assets/default.nix
# Xbox 360 "Blades" dashboard assets for the xbox360 rice: the Convection UI
# font and the dashboard's navigation sound cues. Both are Microsoft's; they are
# taken from a pinned commit of a public Blades recreation
# (David-Lazaro-Fernandez/Audio-Visualizer, whose own code is Apache-2.0 —
# these files are not), so the build never depends on a link that can change.
{ lib, stdenvNoCC, fetchurl, ffmpeg-headless }:

let
  rev = "19f3011ff1e8fe61b4ba3697ce91dabb43f1e7cb";
  base = "https://raw.githubusercontent.com/David-Lazaro-Fernandez/Audio-Visualizer/${rev}/frontend/public/assets";
  fetchAsset = name: path: hash: fetchurl {
    inherit name hash;
    url = "${base}/${lib.replaceStrings [ " " ] [ "%20" ] path}";
  };

  font = fetchAsset "Convection.ttf" "fonts/Convection.ttf"
    "sha256-uL/gS3wu/hVb9jfc3mzxG0c4KoyfKMu8yGfEpFyDX8Y=";

  # Cue name -> source file. The names are what the shell and the controller
  # daemon ask for (`xbox360-sound <cue>`), not the upstream track titles.
  sounds = {
    page-left    = fetchAsset "page-left.mp3"    "sounds/08. Page Left.mp3"  "sha256-Orv/3H43wBBYbpXIEbCBg4PxVG1Sob31oTozn2tPHBw=";
    page-right   = fetchAsset "page-right.mp3"   "sounds/09. Page Right.mp3" "sha256-JHVWCYcEtIrWQ4wlUEPruWg55ZzP40wxW9Qa5FBqKxo=";
    select-a     = fetchAsset "select-a.mp3"     "sounds/10. Select A.mp3"   "sha256-wmjrTU7iZ8uyTP3gZIjIym51Q3cFUre1N95oK1vhA4w=";
    select-b     = fetchAsset "select-b.mp3"     "sounds/12. Select B.mp3"   "sha256-mm2D+5Uwx9E4TB2tKzlqVZk3KSgR83qOb4qpEUgPoNE=";
    select       = fetchAsset "select.mp3"       "sounds/13. Select.mp3"     "sha256-Cbg70JsN7lww6eSInCve+6dwfvsHRUXlGttEtvzG/A8=";
    back         = fetchAsset "back.mp3"         "sounds/14. Back.mp3"       "sha256-BEvP6orqBE6r5gdbsXLZFdiRcO7R74FwUefnT6g7Qg8=";
    notification = fetchAsset "notification.mp3" "sounds/notification.mp3"   "sha256-7UwtFanLWPMMvHCQhcq3O9HY9jv3l3kYw7W6C1iSF5Y=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "xbox360-assets";
  version = "0-unstable-${builtins.substring 0 7 rev}";

  dontUnpack = true;
  nativeBuildInputs = [ ffmpeg-headless ];

  # The cues are decoded to WAV here, once, so playback is `pw-play` with no
  # decoder start-up: a blade switch has to sound on the same frame it moves.
  installPhase = ''
    install -Dm644 ${font} $out/share/fonts/truetype/convection/Convection.ttf
    mkdir -p $out/share/sounds/xbox360
    ${lib.concatStrings (lib.mapAttrsToList (cue: src: ''
      ffmpeg -loglevel error -i ${src} -ar 48000 -ac 2 $out/share/sounds/xbox360/${cue}.wav
    '') sounds)}
  '';

  meta = {
    description = "Xbox 360 Blades dashboard font and UI sounds";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
