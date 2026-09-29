# ~/nixos-config/modules/home-manager/system/fontconfig.nix
{ config, pkgs, lib, ... }:

let
  fc = "${pkgs.fontconfig.bin}/bin";
in
{
  # Rebuild ~/.cache/fontconfig when it has gone stale.
  #
  # fontconfig decides a directory's cache is still valid from (path, mtime).
  # Two of the dirs scanned here are stable paths whose *contents* change every
  # generation — /run/current-system/sw/share/fonts, and
  # /etc/profiles/per-user/<user>/share/fonts, which home-manager registers
  # itself in ~/.config/fontconfig/conf.d/10-hm-fonts.conf — and Nix stamps both
  # with the epoch mtime. The mtime therefore never moves, so `fc-cache -v` says
  #
  #   /run/current-system/sw/share/fonts: skipping, existing cache is valid
  #
  # forever, and a font file renamed by a nixpkgs bump lives on in the user cache
  # as a path that no longer exists. A generic family then resolves to a missing
  # file, which produces *no glyphs at all* rather than a fallback: every
  # character in every GTK/Qt app becomes an empty box.
  #
  # noto-fonts 2026.05.01 did exactly that — the upright variable font
  # NotoSans[wdth,wght].ttf became plain NotoSans.ttf — and VSCode's GTK "Open
  # Folder" dialog came up as solid tofu on gaming-pc while `fc-list` still
  # reported 2167 perfectly healthy fonts and nothing else looked wrong.
  #
  # NixOS's own /etc/fonts/conf.d/00-nixos-cache.conf is immune because it lists
  # *versioned* store paths plus a prebuilt <cachedir>; it is only the per-user
  # cache, which shadows it, that rots. So this belongs in home-manager
  # activation rather than system.activationScripts — it has to run as the user
  # who owns the cache.
  #
  # The probe is three fc-match calls, so a rebuild that changed nothing pays
  # almost nothing; the full rescan only runs on the rebuild that broke a font.
  home.activation.refreshStaleFontCache =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      staleFamily=""

      # An *empty* result means fontconfig has no font for that family at all
      # (a headless host with no fonts installed), which a rescan cannot fix —
      # only a non-empty path pointing at a missing file is the rot we mean.
      for family in sans-serif serif monospace; do
        fontFile="$(${fc}/fc-match -f '%{file}' "$family" 2>/dev/null || true)"
        if [ -n "$fontFile" ] && [ ! -e "$fontFile" ]; then
          staleFamily="$family"
        fi
      done

      if [ -n "$staleFamily" ]; then
        echo "fontconfig: '$staleFamily' resolves to a missing font file, rebuilding the user cache"
        # -r, not -f: erase the caches first so entries for directories that are
        # no longer configured are dropped too, instead of only being rescanned.
        #
        # Deliberately no `exit` on failure — a bare exit in an activation script
        # aborts the whole activation. A font cache is not worth that.
        $DRY_RUN_CMD ${fc}/fc-cache -r || \
          echo "fontconfig: fc-cache failed, fonts may still render as boxes"
      fi
    '';
}
