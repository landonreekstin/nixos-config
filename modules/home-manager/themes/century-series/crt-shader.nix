# ~/nixos-config/modules/home-manager/themes/century-series/crt-shader.nix
# Pure Nix file — import with: import ./crt-shader.nix { }
#
# The century-series CRT screen shader, as a function of the palette so it can
# follow day/night like everything else. Two consumers:
#   hyprland.nix   — writes the DAY shader to the stable path
#                    ~/.config/hypr/shaders/crt-barrel.glsl, which is what
#                    century-crt-toggle turns on.
#   night-mode.nix — generates one shader per ramp step, swapped with
#                    `hyprctl keyword decoration:screen_shader` *only* when a
#                    shader is already active (the filter is opt-in).
#
# The day phosphor constants used to be hardcoded as
#   phosphorAmber = vec3(1.0, 0.62, 0.23)
#   phosphorGreen = vec3(0.498, 0.855, 0.537)
# which are EXACTLY accent-amber and accent-green. Deriving them from the
# palette reproduces the day shader byte-for-byte and makes the night shader
# fall out for free (deep red + ember instead of amber + green).
#
# blueAtten is an extra per-pixel blue cut that only the night end uses. At 1.0
# the line is omitted entirely, so the day output stays byte-identical to the
# pre-refactor shader. This stacks with hyprsunset rather than replacing it:
# hyprsunset warms the whole output via the CTM, this attenuates blue per pixel.
{ ... }:

let
  colors = import ./colors.nix { };
in
{
  mkCrtBarrelShader = c: blueAtten:
    let
      # GLSL header shared by both shaders
      crtGlslHeader = ''
        #version 320 es
        precision highp float;
        in vec2 v_texcoord;
        uniform sampler2D tex;
        out vec4 fragColor;

        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }
      '';

      blueCut =
        if blueAtten >= 1.0 then ""
        else ''

        // === NIGHT BLUE CUT ===
        color.b *= ${toString blueAtten};
'';

      # Shared CRT effects body — sits inside main() after UV is established
      crtEffectsBody = ''
            // === CHROMATIC ABERRATION ===
            float aberration = 0.0006;
            float r = texture(tex, vec2(uv.x - aberration, uv.y)).r;
            float g = texture(tex, uv).g;
            float b = texture(tex, vec2(uv.x + aberration, uv.y)).b;
            vec4 color = vec4(r, g, b, 1.0);

            // === SCANLINES ===
            float scanline = mod(floor(gl_FragCoord.y), 2.0);
            color.rgb *= mix(0.62, 1.0, scanline);

            // === VIGNETTE ===
            float vigX = uv.x * (1.0 - uv.x) * 4.0;
            float vigY = uv.y * (1.0 - uv.y) * 4.0;
            float vignette = pow(vigX * vigY, 0.3);
            vignette = clamp(vignette, 0.6, 1.0);
            color.rgb *= vignette;

            // === DUAL-TONE PHOSPHOR ===
            float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
            vec3 phosphorAmber = ${colors.glslVec3 c.accent-amber};
            vec3 phosphorGreen = ${colors.glslVec3 c.accent-green};
            color.rgb = mix(color.rgb, color.rgb * phosphorAmber, luminance * 0.35);
            color.rgb += phosphorGreen * (1.0 - luminance) * 0.04;

            // === FILM GRAIN ===
            float grain = hash(uv);
            color.rgb += (grain - 0.5) * 0.025;
      ''
      + blueCut
      + ''

            fragColor = color;
      '';
    in ''
      ${crtGlslHeader}
      void main() {
          vec2 uv = v_texcoord;

          // === BARREL DISTORTION ===
          vec2 centered = uv * 2.0 - 1.0;
          float dist = dot(centered, centered);
          uv = (centered * (1.0 + 0.025 * dist)) * 0.5 + 0.5;
          if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
              fragColor = vec4(0.0, 0.0, 0.0, 1.0);
              return;
          }

          ${crtEffectsBody}
      }
    '';
}
