# ~/nixos-config/modules/nixos/homelab/landing-page.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.homelab;

  landingPage = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Homelab</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          background: #0f0f1a;
          color: #e0e0e0;
          font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
          min-height: 100vh;
          padding: 2.5rem 2rem;
        }
        h1 {
          text-align: center;
          margin-bottom: 2.5rem;
          font-size: 1.75rem;
          font-weight: 600;
          color: #7aa2f7;
          letter-spacing: 0.05em;
        }
        .section { margin-bottom: 2rem; }
        .section-title {
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.12em;
          color: #565f89;
          margin-bottom: 0.75rem;
          padding-left: 0.25rem;
        }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
          gap: 0.75rem;
        }
        a.card {
          background: #1a1b2e;
          border: 1px solid #2a2b3d;
          border-radius: 10px;
          padding: 1.25rem 1rem;
          text-decoration: none;
          color: inherit;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 0.5rem;
          transition: background 0.15s, border-color 0.15s, transform 0.15s;
        }
        a.card:hover {
          background: #1e2035;
          border-color: #7aa2f7;
          transform: translateY(-2px);
        }
        .card-icon { font-size: 2rem; line-height: 1; }
        .card-label {
          font-size: 0.875rem;
          font-weight: 500;
          text-align: center;
          color: #c0caf5;
        }
        .card-desc {
          font-size: 0.7rem;
          color: #565f89;
          text-align: center;
        }
        @media (max-width: 480px) {
          .grid { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); }
        }
      </style>
    </head>
    <body>
      <h1>Homelab</h1>

      <div class="section">
        <div class="section-title">Media</div>
        <div class="grid">
          <a class="card" href="http://jellyfin.lan">
            <span class="card-icon">🎬</span>
            <span class="card-label">Jellyfin</span>
            <span class="card-desc">Media Server</span>
          </a>
          <a class="card" href="http://jellyseerr.lan">
            <span class="card-icon">🔍</span>
            <span class="card-label">Jellyseerr</span>
            <span class="card-desc">Requests</span>
          </a>
        </div>
      </div>

      <div class="section">
        <div class="section-title">Downloads</div>
        <div class="grid">
          <a class="card" href="http://transmission.lan">
            <span class="card-icon">⬇️</span>
            <span class="card-label">Transmission</span>
            <span class="card-desc">Torrents</span>
          </a>
          <a class="card" href="http://prowlarr.lan">
            <span class="card-icon">🔎</span>
            <span class="card-label">Prowlarr</span>
            <span class="card-desc">Indexers</span>
          </a>
          <a class="card" href="http://radarr.lan">
            <span class="card-icon">🎥</span>
            <span class="card-label">Radarr</span>
            <span class="card-desc">Movies</span>
          </a>
          <a class="card" href="http://sonarr.lan">
            <span class="card-icon">📺</span>
            <span class="card-label">Sonarr</span>
            <span class="card-desc">TV Shows</span>
          </a>
          <a class="card" href="http://bazarr.lan">
            <span class="card-icon">💬</span>
            <span class="card-label">Bazarr</span>
            <span class="card-desc">Subtitles</span>
          </a>
        </div>
      </div>

      <div class="section">
        <div class="section-title">Home</div>
        <div class="grid">
          <a class="card" href="http://homeassistant.lan">
            <span class="card-icon">🏡</span>
            <span class="card-label">Home Assistant</span>
            <span class="card-desc">Automation</span>
          </a>
          <a class="card" href="https://vaultwarden.lan">
            <span class="card-icon">🔐</span>
            <span class="card-label">Vaultwarden</span>
            <span class="card-desc">Passwords</span>
          </a>
        </div>
      </div>

      <div class="section">
        <div class="section-title">Tools</div>
        <div class="grid">
          <a class="card" href="http://reader.lan">
            <span class="card-icon">🎙️</span>
            <span class="card-label">Article2Pod</span>
            <span class="card-desc">Read → Podcast</span>
          </a>
          <a class="card" href="http://dashboard.lan">
            <span class="card-icon">🎮</span>
            <span class="card-label">Game Dashboard</span>
            <span class="card-desc">Server Control</span>
          </a>
          <a class="card" href="http://nix-cache.lan">
            <span class="card-icon">📦</span>
            <span class="card-label">Nix Cache</span>
            <span class="card-desc">Binary Cache</span>
          </a>
        </div>
      </div>
    </body>
    </html>
  '';
in
{
  config = lib.mkIf cfg.landingPage.enable {
    services.nginx.virtualHosts."home.lan" = {
      root = "${landingPage}";
    };
  };
}
