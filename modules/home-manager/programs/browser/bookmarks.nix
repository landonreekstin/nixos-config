# ~/nixos-config/modules/home-manager/programs/browser/bookmarks.nix
{ lib }:

# The bookmarks toolbar tree, read out of the live places.sqlite on gaming-pc.
#
# Two entries carry credentials. This repo is public, so they are written with
# @PLACEHOLDER@ tokens and substituted at activation from sops secrets — see
# `secretPlaceholders` below and the firefoxBookmarkSecrets activation snippet
# in ./default.nix. Home Manager renders bookmarks.html into the Nix store, so
# a literal token here would be world-readable in /nix/store as well as in git.

let
  dashboardToken = "@DASHBOARD_TOKEN@";
  readerHash = "@READER_HASH@";
in
{
  # placeholder -> sops secret name. Consumed by ./default.nix.
  secretPlaceholders = {
    "@DASHBOARD_TOKEN@" = "browser-dashboard-token";
    "@READER_HASH@" = "browser-reader-hash";
  };

  # True when the tree still contains a placeholder, i.e. the substitution step
  # is required for these bookmarks to work.
  inherit dashboardToken readerHash;

  tree = [
    { name = "YouTube"; url = "https://www.youtube.com/"; }

    { name = "TV"; bookmarks = [
        { name = "HBO Max";     url = "https://play.hbomax.com/home"; }
        { name = "Netflix";     url = "https://www.netflix.com/browse"; }
        { name = "Prime Video"; url = "https://www.amazon.com/gp/video/storefront"; }
        { name = "Peacock";     url = "https://www.peacocktv.com/watch/home"; }
        { name = "Paramount+";  url = "https://www.paramountplus.com/user-profile/whos-watching/"; }
        { name = "Jellyfin";    url = "http://jellyfin.lan/web/#/home"; }
        { name = "Jellyseerr";  url = "http://jellyseerr.lan/"; }
        { name = "Radarr";      url = "http://radarr.lan/"; }
        { name = "Sonarr";      url = "http://sonarr.lan/"; }
        { name = "Bazarr";      url = "http://bazarr.lan/series"; }
        { name = "Indexers - Prowlarr"; url = "http://prowlarr.lan/"; }
        { name = "Downloads";   url = "http://transmission.lan/transmission/web/"; }
        { name = "r/Piracy";    url = "https://old.reddit.com/r/Piracy/wiki/megathread"; }
      ]; }

    { name = "Sports"; bookmarks = [
        { name = "StreamEast";  url = "https://the.streameast.xyz/"; }
        { name = "NFLBite";     url = "https://www.nflbite.is/"; }
        { name = "Sportsurge";  url = "https://v2.sportsurge.net/home5/"; }
        { name = "OnHockey";    url = "https://onhockey.tv/"; }
        { name = "Daily Faceoff"; url = "https://www.dailyfaceoff.com/teams/anaheim-ducks/line-combinations"; }
      ]; }

    { name = "Dev"; bookmarks = [
        { name = "GitHub";      url = "https://github.com/"; }
        { name = "NixOS Options"; url = "https://search.nixos.org/options"; }
        { name = "HM Options";  url = "https://home-manager.dev/manual/23.11/options.xhtml"; }
        { name = "NUR";         url = "https://nur.nix-community.org/"; }
        { name = "plasma-manager"; url = "https://nix-community.github.io/plasma-manager/options.xhtml"; }
        { name = "blind75 cpp"; url = "https://github.com/ankitsamaddar/blind75_cpp_solutions/tree/main"; }
      ]; }

    { name = "AI"; bookmarks = [
        { name = "Gemini";      url = "https://gemini.google.com/app"; }
        { name = "AI Studio";   url = "https://aistudio.google.com/prompts/new_chat"; }
        { name = "Claude";      url = "https://claude.ai/new"; }
        { name = "Usage";       url = "https://claude.ai/settings/usage"; }
        { name = "Claude Status"; url = "https://status.claude.com/"; }
      ]; }

    { name = "Google"; bookmarks = [
        { name = "Drive"; url = "https://drive.google.com/drive/?dmr=1&ec=wgc-drive-hero-goto"; }
        { name = "Gmail"; url = "https://mail.google.com/mail/u/0/#inbox"; }
        { name = "Maps";  url = "https://www.google.com/maps"; }
      ]; }

    { name = "Gaming"; bookmarks = [
        { name = "ProtonDB";    url = "https://www.protondb.com/"; }
        { name = "Vimm";        url = "https://vimm.net/"; }
        { name = "MiSTer FPGA BIOS Checker"; url = "https://takiiiiiiii.github.io/MiSTer_FPGA_BIOS_Checker/"; }
        { name = "HLLRecords";  url = "https://hllrecords.com/profiles/76561198151382680"; }
        { name = "Pokemon on the Analogue Pocket"; url = "https://github.com/ninbura/pokemon-on-the-analogue-pocket#optimal-play-method-per-game"; }
        { name = "Pokemon Database"; url = "https://pokemondb.net/"; }
        { name = "Link's Awakening - Bottle Grotto"; url = "https://www.zeldadungeon.net/links-awakening-walkthrough/bottle-grotto-game-boy-color/"; }
        { name = "Walkthrough: Pokemon Yellow"; url = "https://bulbapedia.bulbagarden.net/wiki/Walkthrough:Pok%C3%A9mon_Yellow"; }
      ]; }

    { name = "Homelab"; bookmarks = [
        { name = "Homelab";     url = "http://home.lan/"; }
        { name = "Home Assistant"; url = "http://homeassistant.lan/home/overview"; }
        { name = "Vaultwarden"; url = "http://vaultwarden.lan/"; }
        { name = "Vaultwarden Admin"; url = "https://vaultwarden.lan/admin"; }
        # Both of the following carry a credential in the URL.
        { name = "Game Servers"; url = "http://dashboard.lan/?token=${dashboardToken}"; }
        { name = "article2pod";  url = "http://reader.lan/ui/${readerHash}"; }
      ]; }

    { name = "Prime";    url = "https://www.amazon.com/amazonprime"; }
    { name = "LinkedIn"; url = "https://www.linkedin.com/feed/"; }
  ];
}
