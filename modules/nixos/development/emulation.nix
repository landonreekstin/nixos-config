# ~/nixos-config/modules/nixos/development/emulation.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.profiles.development.emulation;

  # The card-* helpers live as real .sh files rather than inline Nix strings.
  # They are shell-heavy and full of ${...}, which would need escaping in a Nix
  # '' string; keeping them on disk means they can be shellcheck'd and run
  # standalone. Same idea as development/kernel-files/.
  helperLib = builtins.readFile ./emulation-files/_lib.sh;

  mkCardHelper = name:
    pkgs.writeShellScriptBin name (helperLib + "\n" + builtins.readFile (./emulation-files + "/${name}.sh"));

  cardHelpers = map mkCardHelper [
    "card-status"
    "card-mount"
    "card-unmount"
    "card-backup"
    "card-write"
    "card-verify"
    "card-sweep"
  ];
in
{
  options.customConfig.profiles.development.emulation.devShell = lib.mkOption {
    type = lib.types.package;
    internal = true;
    description = "Dev shell for the ~/emulation FPGA-console workspace.";
  };

  options.customConfig.profiles.development.emulation.enable = with lib; mkOption {
    type = types.bool;
    default = false;
    description = "Enable the emulation workspace dev environment (SD-card management, save analysis, openFPGA tooling).";
  };

  config = lib.mkIf cfg.enable {
    customConfig.profiles.development.emulation.devShell = pkgs.mkShell {
      name = "emulation";

      packages = with pkgs; [
        # --- console tooling ---
        pupdate    # openFPGA core/firmware manager for the Analogue Pocket
        flashgbx   # GBxCart RW Pro: dumping GB/GBA carts and their saves

        # --- SD card and filesystem work ---
        # exfatprogs is the reason this shell exists: the Pocket's 128 GB card
        # migration is to exFAT and mkfs.exfat was not on this machine at all.
        exfatprogs
        dosfstools # mkfs.vfat / fsck.vfat — the current 8 GB cards are FAT32
        mtools     # reads a FAT card without mounting it (NOT exFAT-capable)
        util-linux # lsblk, findmnt — identify cards by UUID, never /dev/sdX
        udisks     # udisksctl: mount/unmount without root. umount is the flush
        rsync
        coreutils  # dd with oflag=direct/iflag=direct, md5sum

        # --- save-file analysis ---
        perl       # the read-crystal/gold/yellow/emerald readers (core modules only)
        hexyl
        vim        # for xxd — REGISTRY.BIN, RTC footers, checksum offsets
        jq
        git

        # --- ROM patching ---
        flips      # IPS/BPS — e.g. the Game Boy Wars 2 English translation
        xdelta

        # --- music library work (see analogue-pocket/docs/MUSIC.md) ---
        # The MP3 player core refuses FLAC at 88.2 kHz and above, so hi-res
        # releases have to be downsampled for the card copy.
        ffmpeg
        flac
        sox
        mp3val
        python3

        # --- archives ---
        # Also installed globally; declared here so the shell stands alone.
        zip
        unzip
        p7zip
      ] ++ cardHelpers;

      shellHook = ''
        export PS1='\[\033[1;34m\][emulation]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
        export DEV_ENV_NAME="emulation"
        echo "--- Emulation Workspace (Pocket / SuperStation1 / Analogue 3D) ---"
        echo "Cards:   card-status, card-mount, card-unmount"
        echo "Rule 0:  card-backup <name>              back up saves on every insertion"
        echo "Rule 13: card-write / card-verify / card-sweep   direct I/O + cold read"
        echo ""
        echo "Cards are addressed by name or UUID, never /dev/sdX."
        echo "The map is cards.tsv in the workspace root."
        echo "------------------------------------------------------------------"
      '';
    };
  };
}
