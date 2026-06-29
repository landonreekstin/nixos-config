# ~/nixos-config/modules/home-manager/scripts/hyprland-keys.nix
# Packages the hyprland-keys GTK4 keybind visualizer from its source repo.
{ pkgs, lib, ... }:

let
  hyprlandKeys = pkgs.python3Packages.buildPythonApplication {
    pname = "hyprland-keys";
    version = "0.1.0";
    format = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "landonreekstin";
      repo  = "hyprland-keys";
      rev   = "502e006108510630928c880a829929dc34f723ef";
      hash  = "sha256-lWbvR235t/qSgR902EpXvVjKS7WA2F6hGB9Q77DEN6s=";
    };

    nativeBuildInputs = [
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];

    buildInputs = [
      pkgs.gtk4
      pkgs.gtk4-layer-shell
      pkgs.gobject-introspection
      pkgs.libadwaita
      pkgs.python3Packages.setuptools
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      pygobject3
    ];

    # Bundle the CSS file so the app can find it at runtime
    postInstall = ''
      install -Dm644 style.css $out/lib/hyprland-keys/style.css
    '';

    # Make gtk4-layer-shell's GObject typelib available at runtime;
    # also tell the app where its CSS file lives.
    preFixup = ''
      gappsWrapperArgs+=(
        --prefix GI_TYPELIB_PATH : "${pkgs.gtk4-layer-shell}/lib/girepository-1.0"
        --prefix LD_LIBRARY_PATH : "${pkgs.gtk4-layer-shell}/lib"
        --set HYPRLAND_KEYS_STYLE "$out/lib/hyprland-keys/style.css"
      )
    '';

    meta.mainProgram = "hyprland-keys";
  };
in
{
  home.packages = [ hyprlandKeys ];
}
