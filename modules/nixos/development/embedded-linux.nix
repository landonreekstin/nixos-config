# ~/nixos-config/modules/nixos/development/embedded-linux.nix
{ lib, config, pkgs, ... }:

let
  cfg = config.customConfig.profiles.development.embedded-linux;
in
{
  # === MODULE OPTIONS ===
  options.customConfig.profiles.development.embedded-linux.components = {
    commonPackages = lib.mkOption {
      type = with lib.types; listOf lib.types.package;
      internal = true;
    };
    qemu = lib.mkOption {
      type = with lib.types; attrsOf lib.types.anything;
      internal = true;
    };
    bbb = lib.mkOption {
      type = with lib.types; attrsOf lib.types.anything;
      internal = true;
    };
  };

  # === MODULE CONFIGURATION ===
  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.embedded-linux.components =
      let
        pkgsQEMU = pkgs.pkgsCross.raspberryPi;
        pkgsBBB = pkgs.pkgsCross.armv7l-hf-multiplatform;
      in
      {
        commonPackages = with pkgs; [
          autoconf automake bison bzip2 cmake flex gawk gcc gettext git gperf
          help2man libtool ncurses patch python3 rsync texinfo unzip wget xz
          qemu_full ubootTools
        ];

        qemu = {
          packages = [ pkgsQEMU.gcc pkgsQEMU.gdb pkgsQEMU.binutils ];
          targetPrefix = pkgsQEMU.stdenv.cc.targetPrefix;
        };

        bbb = {
          packages = [ pkgsBBB.gcc pkgsBBB.gdb pkgsBBB.binutils ];
          targetPrefix = pkgsBBB.stdenv.cc.targetPrefix;
        };
      };
  };
}