# ~/nixos-config/hosts/mini-server/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
      shell.bash.color = "yellow";
      sopsPassword = true;
    };

    system = {
      hostName = "mini-server";
      stateVersion = "25.05";
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

  };

  # Kernel 6.17 caused a kernel panic on this hardware; 6.14 reached EOL in nixpkgs.
  # Pin to 6.12 LTS (maintained through Dec 2026) — re-test with newer kernels periodically.
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Prevent GNOME/logind from suspending or hibernating — this is a server.
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
  };
}
