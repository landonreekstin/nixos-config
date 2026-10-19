# ~/nixos-config/modules/nixos/profiles/vr-srgb-fix/default.nix
# OpenXR layer that fixes washed-out colours in Proton D3D11 VR games (see layer.c).
# Implicit, but only active when XR_SRGB_FIX is set (per-game launch option).
{ stdenv, glslang, openxr-loader, vulkan-headers, xxd }:

stdenv.mkDerivation {
  pname = "xr-srgb-fix";
  version = "1";
  src = ./.;
  nativeBuildInputs = [ glslang xxd ];
  buildInputs = [ openxr-loader vulkan-headers ];

  buildPhase = ''
    runHook preBuild
    glslangValidator -V decode.comp -o decode.spv
    { echo "static const uint32_t decode_spv[] = {"; \
      od -An -v -tx4 decode.spv | sed 's/\([0-9a-f]\{8\}\)/0x\1,/g'; echo "};"; } > decode.spv.h
    $CC -O2 -shared -fPIC -fvisibility=hidden -Wall -o libxr_srgb_fix.so layer.c -ldl -lpthread
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libxr_srgb_fix.so $out/lib/libxr_srgb_fix.so
    mkdir -p $out/share/openxr/1/api_layers/implicit.d
    cat > $out/share/openxr/1/api_layers/implicit.d/XR_APILAYER_NIXOS_srgb_fix.json <<EOF
    {
      "file_format_version": "1.0.0",
      "api_layer": {
        "name": "XR_APILAYER_NIXOS_srgb_fix",
        "library_path": "$out/lib/libxr_srgb_fix.so",
        "api_version": "1.0",
        "implementation_version": "1",
        "description": "Undo the double sRGB encode of Proton D3D11 swapchains",
        "enable_environment": "XR_SRGB_FIX",
        "disable_environment": "XR_SRGB_FIX_DISABLE"
      }
    }
    EOF
    runHook postInstall
  '';
}
