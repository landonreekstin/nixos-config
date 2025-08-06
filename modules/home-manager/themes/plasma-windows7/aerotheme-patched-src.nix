{ pkgs, aerothemeplasma-src }:

pkgs.stdenv.mkDerivation {
  pname = "aerotheme-patched-src";
  version = "6.3.4";

  src = aerothemeplasma-src;

  # We only need the `sed` tool to perform our patches.
  nativeBuildInputs = [ pkgs.gnused ];

  # No build steps needed.
  dontConfigure = true;
  dontBuild = true;

  # This runs after the source is unpacked.
  postPatch = ''
    echo "--- Applying all source code patches ---"

    # Patch #1: Fix the broken QML check in desktopcontainment
    sed -i 's/ecm_find_qmlmodule(org.kde.kirigami REQUIRED)/# ecm_find_qmlmodule(org.kde.kirigami REQUIRED)/' plasma/plasmoids/src/desktopcontainment/CMakeLists.txt
    echo "Patched desktopcontainment."

    # Patch #2: Fix the hardcoded /usr/include paths in seventasks
    sed -i 's|include_directories(/usr/include/Plasma.*)|# &|' plasma/plasmoids/src/seventasks_src/src/CMakeLists.txt
    echo "Patched seventasks."
  '';

  # The install phase just copies the now-patched source tree to the output path.
  installPhase = ''
    cp -r . $out
  '';
}