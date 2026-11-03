# ~/nixos-config/modules/nixos/programs/war-thunder.nix
{ config, pkgs, lib, ... }:

# War Thunder through Gaijin's own Linux launcher, for playing on a Gaijin.net account
# (email + password) instead of the account bound to Steam. Steam's copy is left alone:
# the two keep separate game folders so their updaters never fight over the same files.
#
# The first run downloads the launcher into ~/.local/share/WarThunder. After that the
# launcher updates itself and the game in place, so nothing here lives in the Nix store.
# It is a generic-Linux binary, so it runs under steam-run.
let
  cfg = config.customConfig.programs.warThunder;

  launcher = pkgs.writeShellApplication {
    name = "war-thunder-gaijin";
    runtimeInputs = [ pkgs.curl pkgs.coreutils pkgs.gnutar pkgs.gzip pkgs.steam-run pkgs.zenity ];
    text = ''
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/WarThunder"
      url="https://yupmaster.gaijinent.com/launcher/current.php?id=WarThunderLauncherLinux"
      mkdir -p "$data"

      if [ ! -x "$data/launcher" ]; then
        rm -f "$data/launcher.tar.gz.part"
        { curl -fsSL --connect-timeout 10 -o "$data/launcher.tar.gz.part" "$url"; echo $? > "$data/launcher.rc"; } |
          zenity --progress --pulsate --auto-close --no-cancel --title="War Thunder" \
            --text="Downloading the Gaijin launcher (first run only)..." 2>/dev/null || true
        if [ "$(cat "$data/launcher.rc" 2>/dev/null)" != 0 ] ||
           ! tar -xzf "$data/launcher.tar.gz.part" -C "$data" --strip-components=1; then
          rm -f "$data/launcher.tar.gz.part" "$data/launcher.rc"
          zenity --error --title="War Thunder" --width=440 \
            --text="Couldn't download the Gaijin launcher. Check your internet and try again." 2>/dev/null || true
          exit 1
        fi
        rm -f "$data/launcher.tar.gz.part" "$data/launcher.rc"
      fi

      cd "$data"
      exec steam-run ./launcher "$@"
    '';
  };

  desktop = pkgs.makeDesktopItem {
    name = "war-thunder-gaijin";
    desktopName = "War Thunder (Gaijin)";
    comment = "War Thunder on your Gaijin account";
    exec = "war-thunder-gaijin";
    icon = "steam_icon_236390";
    categories = [ "Game" ];
  };
in
{
  options.customConfig.programs.warThunder.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "War Thunder through Gaijin's own Linux launcher, signed in with a Gaijin.net account.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ launcher desktop ];
  };
}
