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
  # so wait for the keyboard to show up before setting it.
  systemd.services.g915-teal = {
    description = "Set the G915 keyboard lights to teal";
    after = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ config.services.hardware.openrgb.package pkgs.gnugrep ];
    script = ''
      for _ in $(seq 60); do
        if openrgb --client localhost:6742 --list-devices 2>/dev/null | grep -q '^0: G915'; then
          exec openrgb --client localhost:6742 -d 0 -m Direct -c 00B4A0 -b 40
        fi
        sleep 2
      done
      echo "G915 never showed up in OpenRGB" >&2
      exit 1
    '';
  };

  # Firmware updates (`fwupdmgr refresh && fwupdmgr update`). This used to arrive as a
  # `mkDefault true` from services.desktopManager.plasma6 and silently disappeared when
  # KDE was dropped from desktop.environments — it has nothing to do with the desktop, so
  # declare it here instead of letting a session choice decide whether this machine can
  # update its firmware.
  services.fwupd.enable = true;
}
