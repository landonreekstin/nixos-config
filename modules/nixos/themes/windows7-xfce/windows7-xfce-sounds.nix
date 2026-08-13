# ~/nixos-config/modules/nixos/themes/windows7-xfce/windows7-xfce-sounds.nix
{ stdenv, lib, fetchurl, unzip }:

# Windows 7 event sounds packaged as an XDG/libcanberra sound theme ("Windows 7").
# Source: the "Faithful" Vista/7 scheme from ORelio's Sound-Manager-Schemes (a .ths = zip
# of the original Microsoft .wav files). These are Microsoft-proprietary assets — vendored
# for personal use only, NOT redistributable/upstreamable. The Sound Manager filenames map
# to Windows events by convention; we re-map them to freedesktop sound-naming-spec ids.
stdenv.mkDerivation {
  pname = "windows7-xfce-sounds";
  version = "0-unstable-a7e89fc";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/ORelio/Sound-Manager-Schemes/a7e89fc72e768c33ad3f12d2cf868ab6bbc2313d/Windows/Faithful/Windows-Vista-7-Faithful.ths";
    hash = "sha256-eRr9EEUnI6ZwDUzYpu2qBQ6tBrupq0wLgo/b/+UnJ84=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    unzip -o "$src" -d ths
    dir="$out/share/sounds/Windows 7/stereo"
    mkdir -p "$dir"

    printf '%s\n' \
      '[Sound Theme]' \
      'Name=Windows 7' \
      'Comment=Windows 7 event sounds' \
      'Directories=stereo' \
      "" \
      '[stereo]' \
      'OutputProfile=stereo' \
      > "$out/share/sounds/Windows 7/index.theme"

    # map <SoundManager filename> -> <freedesktop event id>
    m() { [ -f "ths/$1.wav" ] && cp "ths/$1.wav" "$dir/$2.wav" || true; }
    m Startup          desktop-login
    m Logoff           desktop-logout
    m Error            dialog-error
    m Warning          dialog-warning
    m Information      dialog-information
    m Default          bell
    m Default          message
    m Email            message-new-instant
    m DeviceConnect    device-added
    m DeviceDisconnect device-removed
    m DeviceFail       device-error
    m RecycleBin       trash-empty
    m Warning          window-attention
    m BatteryLow       battery-low
    m BatteryCritical  battery-caution

    runHook postInstall
  '';

  meta = {
    description = "Windows 7 event sounds as a libcanberra theme (personal-use; MS-proprietary)";
    homepage = "https://github.com/ORelio/Sound-Manager-Schemes";
    platforms = lib.platforms.linux;
  };
}
