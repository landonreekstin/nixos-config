# ~/nixos-config/modules/nixos/programs/keyripple.nix
{ inputs, config, pkgs, lib, ... }:

# Key Ripple (pkgs/keyripple): insideabush's soft gold ripple on each key press of a
# Logitech G915, painted per-key through the OpenRGB server. A host in
# vibeProjects.localApps builds it from his project folder; everyone else gets the pin.
let
  cfg = config.customConfig.programs.keyripple;
  keyripple = pkgs.callPackage ../../../pkgs/keyripple (import "${inputs.self}/pkgs/vibe-local-src.nix" config.customConfig "keyripple");
in
{
  options.customConfig.programs.keyripple = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Key Ripple: a gold ripple on G915 key presses, painted through the OpenRGB server.";
    };
    baseColor = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9A-Fa-f]{6}");
      default = null;
      example = "00B4A0";
      description = "Resting key colour (hex RRGGBB) the ripple is drawn over. null keeps the app's own default (teal at 40 %).";
    };
  };

  config = lib.mkIf cfg.enable {
    # It paints through the OpenRGB server, so it restarts with it (including when a host
    # restarts OpenRGB to re-find the keyboard). The keyboard falls back to its built-in
    # rainbow when it naps, so the app takes the lights back every few seconds.
    # Reads key presses from /dev/input, so it runs as a throwaway user in group input.
    systemd.services.keyripple = {
      description = "Gold ripple on the G915 keys when typing";
      after = [ "openrgb.service" "g915-teal.service" ];
      requires = [ "openrgb.service" ];
      partOf = [ "openrgb.service" ];
      wantedBy = [ "multi-user.target" "openrgb.service" ];
      # Never give up restarting it (the default stops after 5 quick failures).
      startLimitIntervalSec = 0;
      serviceConfig = {
        ExecStart = lib.getExe keyripple;
        DynamicUser = true;
        SupplementaryGroups = [ "input" ];
        Restart = "always";
        RestartSec = 5;
      } // lib.optionalAttrs (cfg.baseColor != null) {
        Environment = "KEYRIPPLE_BASE=${cfg.baseColor}";
      };
    };
  };
}
