{ pkgs, aerothemeplasma-src }:

pkgs.stdenv.mkDerivation {
  pname = "aerotheme-overlay-package";
  version = "6.3.4";

  src = aerothemeplasma-src;

  nativeBuildInputs = [ pkgs.gnutar pkgs.unzip ];
  dontConfigure = true;
  dontBuild = true;

  # This installPhase cherry-picks all the assets we need.
  installPhase = ''
    runHook preInstall
    
    # Kvantum theme
    mkdir -p $out/share/Kvantum
    cp -r $src/misc/kvantum/Kvantum $out/share/

    # Sounds, Icons, Cursors, Mimetypes
    mkdir -p $out/share/sounds
    tar -xf $src/misc/sounds/sounds.tar.gz -C $out/share/sounds
    mkdir -p $out/share/icons
    tar -xf $src/misc/icons/*.tar.gz -C $out/share/icons
    tar -xf $src/misc/cursors/*.tar.gz -C $out/share/icons
    mkdir -p $out/share/mime/packages
    cp $src/misc/mimetype/*.xml $out/share/mime/packages/

    # Plasma assets: Color Scheme, Desktop Theme, L&F, Layouts
    mkdir -p $out/share/color-schemes
    cp $src/plasma/color_scheme/*.colors $out/share/color-schemes/
    mkdir -p $out/share/plasma
    cp -r $src/plasma/desktoptheme/. $out/share/plasma/desktoptheme/
    cp -r $src/plasma/look-and-feel/. $out/share/plasma/look-and-feel/
    cp -r $src/plasma/layout-templates/. $out/share/plasma/layout-templates/

    # Non-compiled QML plasmoids
    mkdir -p $out/share/plasma/plasmoids
    for dir in $src/plasma/plasmoids/*; do
        local name=$(basename "$dir")
        if [[ "$name" != "src" && "$name" != "io.gitgud.wackyideas.desktopcontainment" && "$name" != "io.gitgud.wackyideas.seventasks" && "$name" != "io.gitgud.wackyideas.SevenStart" && "$name" != "io.gitgud.wackyideas.volume" ]]; then
            cp -r "$dir/." "$out/share/plasma/plasmoids/$name/"
        fi
    done
    
    runHook postInstall
  '';
}