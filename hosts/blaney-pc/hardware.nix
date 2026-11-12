# ~/nixos-config/hosts/blaney-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    unstable = false; # Older hardware — use stable 6.12 LTS kernel + stable NVIDIA
    nvidia = {
      enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
    };
    peripherals = {
      enable = true; # Enable peripheral configurations
      openrgb.enable = true; # Enable OpenRGB for RGB control
      openrazer.enable = true; # Enable OpenRazer for Razer device support
      ckb-next.enable = false; # Enable CKB-Next for Corsair device support
      input-remapper.enable = true;
      solaar.enable = true;
    };
    wifi.waybar.enable = true;  # USB WiFi dongle (wlp38s0f3u1) — picker in the Hyprland bar
  };

  # Lets his session talk to the Acer's brightness over DDC/CI (screen-light, home.nix).
  hardware.i2c.enable = true;
  services.udev.packages = [ pkgs.ddcutil ];

  # The AMD 500-series chipset xHCI controller (0000:02:00.0, USB bus 1/2 — the G915
  # receiver lives there) fails S3 resume: "xHC error in resume, USBSTS 0x401, Reinit",
  # then Logitech HID++ protocol errors and dead input until the receiver is replugged.
  # Unbinding and rebinding the controller after wake re-enumerates it from scratch.
  # Not done before suspend, so a keypress can still wake the PC.
  powerManagement.resumeCommands = ''
    xhci=0000:02:00.0
    if [ -e /sys/bus/pci/drivers/xhci_hcd/$xhci ]; then
      echo $xhci > /sys/bus/pci/drivers/xhci_hcd/unbind
      sleep 1
    fi
    echo $xhci > /sys/bus/pci/drivers/xhci_hcd/bind

    # Hyprland's libinput misses the remove/re-add that the rebind causes (it is still
    # busy waking the GPU), so the keyboard works on a TTY but not on the desktop. A VT
    # round-trip makes the compositor drop and re-open every input device. Wait for the
    # receiver first: a stuck device on another port can hold enumeration up for ~25s.
    for _ in $(seq 60); do
      ls /dev/input/by-id/*G915*-event-kbd >/dev/null 2>&1 && break
      sleep 1
    done
    sleep 1
    vt=$(${pkgs.kbd}/bin/fgconsole)
    ${pkgs.kbd}/bin/chvt 12
    sleep 1
    ${pkgs.kbd}/bin/chvt "$vt"

    # The receiver came back from scratch, so put the teal back on the keys.
    systemctl restart --no-block g915-teal.service
  '';

  # Keep his G915 keys a soft Glade teal. Solaar can't make lighting stick over the
  # wireless receiver, but OpenRGB 1.1 drives it; without this the server grabs the
  # keyboard and the keys go dark. The server finds devices a while after it starts,
  # so wait for the keyboard to show up before setting it. Over the cable it is listed
  # as "Logitech G915 ... (Wired)" and not always first, so find it by name.
  # OpenRGB only looks for devices when it starts, so plugging the keyboard's cable in or
  # out later left the keys on their own rainbow. Each time, restart OpenRGB and re-apply.
  services.udev.extraRules = ''
    ACTION=="add|remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="46d/c33e/*", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart g915-replug.service"
  '';
  systemd.services.g915-replug = {
    description = "Re-find the G915 after its cable is plugged in or out";
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 3   # let it reconnect (wired, or back on the wireless receiver)
      ${pkgs.systemd}/bin/systemctl restart openrgb.service
      ${pkgs.systemd}/bin/systemctl restart g915-teal.service
    '';
  };

  systemd.services.g915-teal = {
    description = "Set the G915 keyboard lights to teal";
    after = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ config.services.hardware.openrgb.package pkgs.gnugrep pkgs.coreutils ];
    script = ''
      for _ in $(seq 60); do
        ids=$(openrgb --client localhost:6742 --list-devices 2>/dev/null \
          | grep -E '^[0-9]+: .*G915' | cut -d: -f1 || true)
        if [ -n "$ids" ]; then
          # The server can list one keyboard twice; set every entry.
          for id in $ids; do
            openrgb --client localhost:6742 -d "$id" -m Direct -c 00B4A0 -b 40
          done
          exit 0
        fi
        sleep 2
      done
      echo "G915 never showed up in OpenRGB" >&2
      exit 1
    '';
  };

  # A soft gold ripple on each key press, over the teal (his own app, pkgs/keyripple,
  # built here from ~/projects/keyripple). It paints through the OpenRGB server, so it
  # restarts with it (including after the cable is plugged in or out, g915-replug).
  # Reads key presses from /dev/input, so it runs as a throwaway user in group input.
  systemd.services.keyripple = {
    description = "Gold ripple on the G915 keys when typing";
    after = [ "openrgb.service" "g915-teal.service" ];
    requires = [ "openrgb.service" ];
    partOf = [ "openrgb.service" ];
    wantedBy = [ "multi-user.target" "openrgb.service" ];
    serviceConfig = {
      ExecStart = lib.getExe (pkgs.callPackage ../../pkgs/keyripple
        (import ../../pkgs/vibe-local-src.nix config.customConfig "keyripple"));
      DynamicUser = true;
      SupplementaryGroups = [ "input" ];
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Firmware updates (`fwupdmgr refresh && fwupdmgr update`). This used to arrive as a
  # `mkDefault true` from services.desktopManager.plasma6 and silently disappeared when
  # KDE was dropped from desktop.environments — it has nothing to do with the desktop, so
  # declare it here instead of letting a session choice decide whether this machine can
  # update its firmware.
  services.fwupd.enable = true;
}
