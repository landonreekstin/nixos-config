# ~/nixos-config/modules/home-manager/themes/century-series/colors.nix
#
# The century-series palette, in two variants, plus the day->night interpolator.
#
#   centuryColors       DAY. A daylight Cold War cockpit: amber CRT accents and
#                       phosphor green on dark blue-grey instrument panels.
#   centuryNightColors  NIGHT. The same cockpit on a night sortie: F-117/B-2
#                       stealth black under red instrument flood. Every value
#                       satisfies blue <= red, so there is little blue left for
#                       hyprsunset to have to warm away.
#
# Both variants carry the SAME KEYS, and every consumer interpolates them as
# `${c.<key>}`. That is the whole trick: remapping accent-green / accent-radar /
# info-blue to warm values here reskins ~200 waybar CSS references and every
# other generated config without editing a single one of them.
#
# Keys named for a day colour (accent-amber, accent-green) keep their day
# *meaning* at night -- primary accent, "nominal/ok" accent -- not their day
# hue. Renaming them would mean editing all 14 consumers for no gain.
#
# paletteSteps pre-bakes the ramp at build time so the runtime switcher
# (night-mode.nix) never does colour arithmetic in bash.
#
# Interpolation is in HSL with shortest-arc hue, NOT sRGB: lerping
# #39ff14 -> #ff1b08 in sRGB passes through a dead khaki midpoint, while HSL
# takes it through yellow and orange -- panel lights warming up. Endpoints are
# kept exact by construction rather than trusting the HSL round trip.
#
# Not a module -- imported as `import ./colors.nix { }` from ~14 call sites, so
# it cannot see customConfig and must use builtins only (most call sites pass
# no `lib`). Note Nix needs spaces around `/` or it parses as a path.
{ ... }:

let
  # --- hex <-> int ----------------------------------------------------------
  hexDigit = {
    "0" = 0;  "1" = 1;  "2" = 2;  "3" = 3;  "4" = 4;  "5" = 5;  "6" = 6;  "7" = 7;
    "8" = 8;  "9" = 9;  "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
    "A" = 10; "B" = 11; "C" = 12; "D" = 13; "E" = 14; "F" = 15;
  };

  fromHexPair = s:
    hexDigit.${builtins.substring 0 1 s} * 16 + hexDigit.${builtins.substring 1 1 s};

  # 255 -> "ff"  (clamped; Nix `/` is integer division on ints and there is no `%`)
  toHexPair = n:
    let
      v = if n < 0 then 0 else if n > 255 then 255 else n;
      digits = "0123456789abcdef";
    in builtins.substring (v / 16) 1 digits
     + builtins.substring (v - (v / 16) * 16) 1 digits;

  # Channel at byte offset i of "#rrggbb[aa]" as an int 0..255
  channel = s: i: fromHexPair (builtins.substring i 2 s);

  # --- HSL ------------------------------------------------------------------
  fmin = a: b: if a < b then a else b;
  fmax = a: b: if a > b then a else b;

  rgbToHsl = r: g: b:
    let
      rf = r / 255.0; gf = g / 255.0; bf = b / 255.0;
      mx = fmax rf (fmax gf bf);
      mn = fmin rf (fmin gf bf);
      l = (mx + mn) / 2.0;
      d = mx - mn;
      s = if d == 0.0 then 0.0
          else if l > 0.5 then d / (2.0 - mx - mn)
          else d / (mx + mn);
      h0 = if d == 0.0 then 0.0
           else if mx == rf then 60.0 * ((gf - bf) / d)
           else if mx == gf then 60.0 * (2.0 + (bf - rf) / d)
           else 60.0 * (4.0 + (rf - gf) / d);
    in { h = if h0 < 0.0 then h0 + 360.0 else h0; inherit s l; };

  hueToRgb = p: q: t0:
    let t = if t0 < 0.0 then t0 + 1.0 else if t0 > 1.0 then t0 - 1.0 else t0;
    in if t < 1.0 / 6.0 then p + (q - p) * 6.0 * t
       else if t < 0.5 then q
       else if t < 2.0 / 3.0 then p + (q - p) * (2.0 / 3.0 - t) * 6.0
       else p;

  hslToRgb = h: s: l:
    let
      q = if l < 0.5 then l * (1.0 + s) else l + s - l * s;
      p = 2.0 * l - q;
      hk = h / 360.0;
      ch = t: builtins.floor ((if s == 0.0 then l else hueToRgb p q t) * 255.0 + 0.5);
    in { r = ch (hk + 1.0 / 3.0); g = ch hk; b = ch (hk - 1.0 / 3.0); };

  # Interpolate two "#rrggbb" or "#rrggbbaa" values. t = 0 -> a, t = 1 -> b.
  #
  # Hybrid on purpose. HSL shortest-arc hue is what gives the accents their
  # "panel lights warming up" sweep (#39ff14 -> yellow -> orange -> #ff2a1a).
  # But for a near-grey the hue is almost meaningless and the shortest arc from
  # blue-black to warm-black runs through PURPLE, which is the one hue family a
  # blue-light theme should never visit. So anything with little chroma is
  # blended straight in sRGB, where a desaturated path is the honest one.
  #
  # chroma here is the HSL chroma, s * (1 - |2l - 1|). The 0.15 gate puts the
  # accents, radar and info-blue on the HSL path and the backgrounds, bezels
  # and text on the sRGB path -- checked per key in the eval test.
  chromaOf = hsl: hsl.s * (1.0 - (if 2.0 * hsl.l - 1.0 < 0.0
                                  then 1.0 - 2.0 * hsl.l
                                  else 2.0 * hsl.l - 1.0));

  lerpHex = a: b: t:
    let
      ha = rgbToHsl (channel a 1) (channel a 3) (channel a 5);
      hb = rgbToHsl (channel b 1) (channel b 3) (channel b 5);

      useHsl = (fmin (chromaOf ha) (chromaOf hb)) >= 0.15;

      # --- HSL path: shortest-arc hue. An achromatic endpoint has no
      # meaningful hue, so it borrows the other's.
      h1 = if ha.s == 0.0 then hb.h else ha.h;
      h2 = if hb.s == 0.0 then ha.h else hb.h;
      dh0 = h2 - h1;
      dh = if dh0 > 180.0 then dh0 - 360.0
           else if dh0 < (0.0 - 180.0) then dh0 + 360.0
           else dh0;
      hm0 = h1 + dh * t;
      hm = if hm0 < 0.0 then hm0 + 360.0 else if hm0 >= 360.0 then hm0 - 360.0 else hm0;
      hslRgb = hslToRgb hm (ha.s + (hb.s - ha.s) * t) (ha.l + (hb.l - ha.l) * t);

      # --- sRGB path
      mixCh = i: builtins.floor
        ((channel a i) + ((channel b i) - (channel a i)) * t + 0.5);
      rgb = if useHsl then hslRgb else { r = mixCh 1; g = mixCh 3; b = mixCh 5; };

      alphaA = builtins.substring 7 2 a;
      alphaB = builtins.substring 7 2 b;
      alphaM = toHexPair (builtins.floor
        ((fromHexPair alphaA) + ((fromHexPair alphaB) - (fromHexPair alphaA)) * t + 0.5));
    in "#" + toHexPair rgb.r + toHexPair rgb.g + toHexPair rgb.b
     + (if alphaA != "" && alphaB != "" then alphaM else alphaA);

  # -------------------------------------------------------------------------
  # DAY -- unchanged. Any edit here changes the live theme on seven hosts.
  # -------------------------------------------------------------------------
  day = {
    # Base colors - Instrument panel backgrounds
    bg-primary = "#0a0e14";      # Deep panel black
    bg-secondary = "#1a1f29";    # Secondary panel
    bg-tertiary = "#141920";     # Raised elements

    # Structural colors - MFD frames and bezels
    border-primary = "#2a3441";   # Gunmetal frame
    border-secondary = "#3d4654"; # Lighter bezel
    border-active = "#4a5568";    # Active/focused frame

    # Primary accent - Amber CRT displays (radar altimeter, navigation)
    accent-amber = "#ff9e3b";     # Main amber
    accent-amber-dim = "#cc7e2f"; # Dimmed amber
    accent-amber-glow = "#ffb454"; # Glowing amber

    # Secondary accent - Green phosphor (attitude indicator, radar)
    accent-green = "#7fda89";     # Phosphor green
    accent-green-dim = "#5cb36a"; # Dimmed green
    accent-radar = "#39ff14";     # Intense radar green

    # Text colors - Instrument markings
    text-primary = "#e6e1cf";     # Off-white markings
    text-secondary = "#a6a69c";   # Dimmed text
    text-tertiary = "#6a6a5e";    # Very dim text

    # Warning/Caution system
    warning-red = "#ff3838";      # Master warning
    warning-orange = "#ff7a1a";   # Low fuel / approaching critical
    caution-yellow = "#ffb454";   # Caution/advisory
    caution-yellow-green = "#c8dc30"; # Advisory / mid-range
    info-blue = "#5ccfe6";        # Information

    # Material colors
    metal = "#4a5568";            # Brushed aluminum
    metal-dark = "#2d3748";       # Dark steel
    glass = "#1a1f2980";          # Tinted glass overlay

    # --- Lifted out of hardcoded call sites so the night variant can reach
    # them. Day values are byte-identical to the literals they replace, so the
    # day build is unchanged -- see the generated-config diff in the PR.
    weather-snow = "#b0d4ff";     # was waybar.nix:648 literal
    temp-cool = "#ffe8a0";        # was waybar.nix:706 literal
    temp-cool-dim = "#ccba70";    # was waybar.nix:707 literal
    # ckb-next WIDGET swatches (waybar.nix:523-552 literals). These are the
    # bar's colours only -- the keyboard's own four cycle constants stay in
    # ckb-scripts.nix, which is contracted to match
    # modules/nixos/hardware/peripherals.nix. Decoupled on purpose: the LEDs
    # are user state, the swatch is theme.
    kbd-radar = "#39ff14";
    kbd-amber = "#ff7a1a";
    kbd-red = "#cc0000";
    kbd-mig = "#00c8b4";
  };

  # -------------------------------------------------------------------------
  # NIGHT -- F-117 / B-2 night-mission stealth cockpit.
  #
  # Rules, in priority order:
  #  1. Melanopic suppression. Deep red has near-zero ipRGC response, so every
  #     value holds blue <= red. The day backgrounds actually violate this
  #     (#0a0e14 is blue-cast: B=0x14 > R=0x0a) -- flipping that is the single
  #     biggest perceptual change here.
  #  2. Night-mission reading. Both airframes are flat-black RAM over a
  #     red-flooded cockpit, so backgrounds go blue-black -> warm near-black,
  #     bezels gunmetal -> oxidised iron, and the green-phosphor ladder (which
  #     has no business in a night cockpit) becomes an ember-amber ladder --
  #     keeping the day theme's two-accent hierarchy without any green.
  #  3. Dimmer, not just redder: accent luminance drops ~50%, text ~12%.
  #
  # Hue is spent once everything is red, so SEVERITY IS CARRIED BY BRIGHTNESS:
  # warnings go hotter and whiter rather than redder, and caution-yellow is
  # deliberately kept as the one high-luminance "this is different" channel.
  # That is the judgement call here most likely to want tuning on real glass.
  # -------------------------------------------------------------------------
  night = {
    # Faceted RAM skin -- same lightness as day, hue flipped off blue
    bg-primary = "#0a0604";
    bg-secondary = "#1a0f0b";
    bg-tertiary = "#120a07";

    # Oxidised iron bezels. Slightly lighter than day: the blue tint that gave
    # the day bezels their separation is gone, so lightness has to replace it.
    border-primary = "#3a1c18";
    border-secondary = "#55261f";
    border-active = "#6e3028";

    # Primary accent - red instrument flood. Not pure #ff0000: at 13px on an
    # LCD that fringes on the RGB subpixels and reads as noise. A ~5 degree
    # orange shift keeps strokes solid. 5.4:1 on bg-primary, passes AA.
    accent-amber = "#ff4538";
    accent-amber-dim = "#c42e22";
    accent-amber-glow = "#ff6a4d";

    # Secondary accent - ember amber, standing in for phosphor green. ~35
    # degrees of hue separation from the red accent, which is enough to stay
    # distinguishable at these luminances.
    accent-green = "#d98a2b";
    accent-green-dim = "#a66420";
    # Radar green -> RWR red. Semantically better than the day value: a real
    # RWR threat symbol is red.
    accent-radar = "#ff2a1a";

    # Red-lit instrument markings
    text-primary = "#dfbda6";     # warm parchment, 11:1 on bg
    text-secondary = "#a8826f";   # 5.7:1
    # Deliberately lighter than day: the warm hue costs perceived contrast, so
    # it needs the luminance back.
    text-tertiary = "#7d5848";

    # Warning/Caution - brightness as the severity channel
    warning-red = "#ff1f14";
    warning-orange = "#ff6a00";
    caution-yellow = "#ffb070";       # the reserved high-luminance channel
    caution-yellow-green = "#e08a28"; # day's worst value for night use
    info-blue = "#d4714a";            # the banned colour -> muted terracotta

    # Material colors
    metal = "#6e3028";
    metal-dark = "#3a1c18";
    glass = "#1a0f0b80";

    # Lifted keys (see day block)
    weather-snow = "#e8c0a8";     # no cold blue for snow after dark
    temp-cool = "#ffcfa8";
    temp-cool-dim = "#c4906a";
    kbd-radar = "#ff2a1a";
    kbd-amber = "#ff6a00";
    kbd-red = "#ff1f14";
    kbd-mig = "#c4703a";
  };

  # --- build-time guards ----------------------------------------------------
  # A silently-wrong palette is expensive to notice, so make it a build error.
  keyNames = builtins.attrNames day;
  keysMatch = keyNames == builtins.attrNames night;
  # Rule 1 above, mechanically checked for every night value.
  warmOnly = builtins.all (k: (channel night.${k} 5) <= (channel night.${k} 1)) keyNames;

in
assert keysMatch;
assert warmOnly;

rec {
  centuryColors = day;
  centuryNightColors = night;

  inherit lerpHex;

  # "#rrggbb" or "#rrggbbaa" -> { r; g; b; a; }, r/g/b ints 0..255 and a a
  # float 0..1. night-mode.nix uses this to emit GTK `@define-color`, which
  # takes #rrggbb or rgba() but REJECTS 8-digit hex.
  rgbaOf = s: {
    r = channel s 1;
    g = channel s 3;
    b = channel s 5;
    a = if builtins.substring 7 2 s == "" then 1.0 else (channel s 7) / 255.0;
  };

  # Palette at position t along the ramp (0 = day, 1 = night).
  lerpPalette = t: builtins.mapAttrs (k: v: lerpHex v night.${k} t) day;

  # [ day, ..., night ] -- n steps yields n+1 palettes. The endpoints are the
  # literal attrsets, never a round-tripped approximation of them.
  paletteSteps = n:
    if n <= 1 then [ day night ]
    else [ day ]
      ++ builtins.genList (i: lerpPalette ((i + 1) * 1.0 / (n * 1.0))) (n - 1)
      ++ [ night ];

  # "#ff9e3b" -> "vec3(1.000, 0.620, 0.231)" for the CRT screen shader.
  # The day shader's phosphor constants are exactly accent-amber and
  # accent-green, so deriving them means the shader follows the palette for
  # free instead of restating the vec3s.
  glslVec3 = s:
    let
      f = i: builtins.floor ((channel s i) * 1000.0 / 255.0 + 0.5);
      d = i:
        let
          v = f i;
          frac = toString (v - (v / 1000) * 1000);
          pad = if builtins.stringLength frac == 1 then "00${frac}"
                else if builtins.stringLength frac == 2 then "0${frac}"
                else frac;
        in "${toString (v / 1000)}.${pad}";
    in "vec3(${d 1}, ${d 3}, ${d 5})";

  # Configuration object (can be extended in the future for accent mode, border style, etc.)
  centuryConfig = {
    accentMode = "mixed";  # Future: could be made configurable via customConfig
    borderStyle = "mfd";   # Future: could be made configurable via customConfig
  };
}
