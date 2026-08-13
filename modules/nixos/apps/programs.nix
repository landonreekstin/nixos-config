# ~/nixos-config/modules/nixos/apps/programs.nix
{ lib, pkgs, config, ... }:

# The user-application registry. Nothing on the NixOS side implements it — it is
# read by the home-manager modules that install and launch these apps — so it is
# declared here rather than colocated with an implementing module. It cannot move
# to modules/home-manager: home-manager receives customConfig as a plain attrset
# via extraSpecialArgs, not as its own option tree.

let
  # Builds one entry of customConfig.apps.programs.<role>.
  #
  # Each user application is declared once, as a package plus the command used to
  # launch it, and the command is *derived* from the package. That linkage is the
  # whole point: setting `package = null` both drops the install and empties the
  # command, so no store path is left dangling in a keybind (an interpolated
  # "${pkgs.foo}/bin/foo" default pulls foo into the closure even when foo is not
  # in home.packages — the trap that made removing librewolf so awkward).
  #
  # `exe` is given explicitly rather than using lib.getExe because several
  # packages' binary names differ from their attribute name (bitwarden-desktop ->
  # bitwarden, vscode -> code, btop-rocm -> btop, neovim -> nvim) and
  # meta.mainProgram is not reliably set for all of them.
  mkAppRole =
    { package ? null
    , exe ? null
    , args ? ""
    , command ? null   # for roles installed elsewhere (e.g. the gaming profile)
    , description
    }:
    lib.mkOption {
      inherit description;
      default = {};
      type = lib.types.submodule ({ config, ... }: {
        options = {
          package = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = package;
            description = "Package to install for this role. null means do not install it.";
          };
          exe = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = exe;
            description = ''
              Name of the binary inside `package`, used to derive `command`.
              Override this alongside `package` when swapping in an application
              whose binary is named differently (e.g. vesktop for the chat role).
            '';
          };
          args = lib.mkOption {
            type = lib.types.str;
            default = args;
            description = "Arguments appended to the derived `command`.";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = ''
              Command used to launch this application. Derived from `package` and
              `exe` by default. An empty string means the role is unset: no
              keybind is emitted for it.
            '';
          };
        };
        # mkDefault so a host can override the command on its own (e.g. to launch
        # a Flatpak) without having to restate the package.
        config.command = lib.mkDefault (
          if config.package == null then (if command != null then command else "")
          else "${config.package}/bin/${config.exe}${config.args}"
        );
      });
    };

in
{
  options.customConfig.apps = with lib; {
    # ------------------------------------------------------------------------ #
    # User applications
    #
    # The set of user-facing programs a machine installs. These used to be
    # hardcoded in modules/home-manager/hyprland/functional.nix, which made the
    # app set invisible from the host file and impossible to override. Desktop
    # *environment* infrastructure (waybar, rofi, hyprsunset, swaylock, fonts,
    # portals) still belongs to the Hyprland module — only user applications
    # live here.
    #
    # The defaults reproduce the full "complete DE" experience, so a host that
    # says nothing gets everything. To drop an app, set its package to null:
    #
    #   apps.programs.browser = {
    #     package = null;                                 # not installed
    #     command = "flatpak run org.chromium.Chromium";  # keybind still works
    #   };
    #
    # Leaving `command` unset alongside `package = null` also removes the
    # application's Hyprland keybind.
    # ------------------------------------------------------------------------ #
    programs = {
      enable = mkOption {
        type = types.bool;
        default = lib.elem "hyprland" config.customConfig.desktop.environments;
        defaultText = literalExpression ''lib.elem "hyprland" config.customConfig.desktop.environments'';
        description = ''
          Install the customConfig user application set. Defaults to enabled on
          Hyprland hosts, which is where this set was previously hardcoded;
          KDE-only hosts opt in explicitly.
        '';
      };

      # ── Browsers ──────────────────────────────────────────────────────────
      browser = mkAppRole {
        package = pkgs.librewolf; exe = "librewolf";
        description = "Primary web browser (Super+B).";
      };
      browserAlt = mkAppRole {
        package = pkgs.brave; exe = "brave";
        description = "Alternative web browser (Super+Alt+B).";
      };

      # ── Terminal and file management ──────────────────────────────────────
      terminal = mkAppRole {
        package = pkgs.kitty; exe = "kitty";
        description = "Terminal emulator; backs the \$terminal Hyprland variable (Super+Return).";
      };
      fileManager = mkAppRole {
        package = pkgs.kdePackages.dolphin; exe = "dolphin";
        description = "Graphical file manager; backs the \$fileManager Hyprland variable (Super+Alt+F).";
      };
      fileManagerTUI = mkAppRole {
        package = pkgs.yazi; exe = "yazi";
        description = "Terminal file manager (Super+F, opened inside \$terminal).";
      };

      # ── Editors ───────────────────────────────────────────────────────────
      editor = mkAppRole {
        package = pkgs.kdePackages.kate; exe = "kate";
        description = "Graphical text editor (Super+T).";
      };
      editorTUI = mkAppRole {
        package = pkgs.neovim; exe = "nvim";
        description = "Terminal text editor; backs the nvim-kitty.desktop MIME wrapper.";
      };
      ide = mkAppRole {
        package = pkgs.vscode; exe = "code";
        description = "IDE / code editor (Super+I).";
      };

      # ── System ────────────────────────────────────────────────────────────
      taskManager = mkAppRole {
        package = pkgs.btop-rocm; exe = "btop";
        description = "Task manager (Ctrl+Shift+Escape, opened inside \$terminal).";
      };
      passwordManager = mkAppRole {
        package = pkgs.bitwarden-desktop; exe = "bitwarden";
        description = "Password manager (Super+P).";
      };

      # ── Communication ─────────────────────────────────────────────────────
      chat = mkAppRole {
        package = pkgs.discord; exe = "discord";
        description = "Primary chat application (Super+C).";
      };
      chatAlt = mkAppRole {
        package = pkgs.signal-desktop; exe = "signal-desktop";
        description = "Alternative chat application (Super+Alt+C).";
      };

      # ── Media ─────────────────────────────────────────────────────────────
      music = mkAppRole {
        package = pkgs.spotify; exe = "spotify";
        args = " --enable-features=UseOzonePlatform --ozone-platform=wayland";
        description = "Music player (Super+M).";
      };
      audioVisualizer = mkAppRole {
        package = pkgs.cava; exe = "cava";
        description = "Audio visualizer (Super+Alt+M, opened inside \$terminal).";
      };
      videoPlayer = mkAppRole {
        package = pkgs.mpv; exe = "mpv";
        description = "Video and audio player; the MIME default for video/* and audio/*.";
      };
      imageViewer = mkAppRole {
        package = pkgs.imv; exe = "imv";
        description = "Image viewer; the MIME default for image/*.";
      };
      pdfReader = mkAppRole {
        package = pkgs.zathura; exe = "zathura";
        description = "PDF reader; the MIME default for application/pdf.";
      };
      archiveManager = mkAppRole {
        package = pkgs.file-roller; exe = "file-roller";
        description = "Archive manager; the MIME default for archive types.";
      };

      # ── Gaming ────────────────────────────────────────────────────────────
      # Installed by customConfig.profiles.gaming (a profile, not an app set),
      # so these carry no package and resolve from PATH.
      gaming = mkAppRole {
        command = "steam";
        description = "Primary gaming platform (Super+G). Installed by the gaming profile.";
      };
      gamingAlt = mkAppRole {
        command = "lutris";
        description = "Alternative gaming platform (Super+Alt+G). Installed by the gaming profile.";
      };
    };
  };
}
