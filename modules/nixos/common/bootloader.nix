# ~/nixos-config/modules/nixos/common/bootloader.nix
{ config, pkgs, lib, ... }:
let
  quietBootEnabled = config.customConfig.bootloader.quietBoot;
  plymouthEnabled = config.customConfig.bootloader.plymouth.enable;
  quietOrPlymouth = quietBootEnabled || plymouthEnabled;
  plymouthTheme = config.customConfig.bootloader.plymouth.theme;
  # Extract only the selected theme from the 289MB adi1090x collection so the
  # initrd doesn't bloat (including the full package pushes initrd to 250MB+).
  selectedThemePkg = pkgs.runCommand "plymouth-theme-${plymouthTheme}" {} ''
    mkdir -p $out/share/plymouth/themes
    cp -r ${pkgs.adi1090x-plymouth-themes}/share/plymouth/themes/${plymouthTheme} \
      $out/share/plymouth/themes/
  '';
in
{
  options.customConfig.bootloader = with lib; {
    configurationLimit = mkOption {
      type = types.int;
      default = 10;
      description = "Maximum number of NixOS generations to keep in the boot menu. Lower for smaller /boot partitions.";
      example = 3;
    };
    quietBoot = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable quiet boot (suppress boot messages).";
    };
    plymouth = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Plymouth boot splash screen.";
      };
      theme = mkOption {
        type = types.str;
        default = "spinner";
        description = "Plymouth theme to use. Bundled options: spinner, bgrt, breeze, spinfinity.";
      };
    };
  };

  config = {
    boot.loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = config.customConfig.bootloader.configurationLimit;
      };
      efi.canTouchEfiVariables = true;
    };

    boot.plymouth = lib.mkIf plymouthEnabled {
      enable = true;
      theme = plymouthTheme;
      themePackages = [ selectedThemePkg ];
    };

    boot.initrd.verbose = !quietOrPlymouth;
    boot.loader.timeout = if quietBootEnabled then 0 else 5;
    boot.consoleLogLevel = if quietOrPlymouth then 0 else 4;
    boot.kernelParams = lib.mkIf quietOrPlymouth [
      "quiet"
      "splash"
      "udev.log_level=3"
      "rd.udev.log_level=3"
    ];
  };
}