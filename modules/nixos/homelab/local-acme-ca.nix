# ~/nixos-config/modules/nixos/homelab/local-acme-ca.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.homelab;
  caDir = "/var/lib/step-ca";
  # systemd DynamicUser+StateDirectory locks caDir to mode 700 (step-ca owner only).
  # Copy the root cert here so nginx can read it without privilege.
  publicCaDir = "/var/lib/homelab-ca";
  rootCACert = ./ca/root_ca.crt;
in
{
  config = lib.mkMerge [

  (lib.mkIf cfg.localCA.trustCA {
    security.pki.certificateFiles = [ rootCACert ];
  })

  (lib.mkIf cfg.localCA.enable {

    # World-readable directory for the root cert served over HTTP.
    systemd.tmpfiles.rules = [
      "d ${publicCaDir} 0755 root root - -"
    ];

    # Bootstrap the CA on first activation if not already initialized.
    # Runs as root; chown transfers ownership to the step-ca system user so
    # the service can read the key files at runtime.
    system.activationScripts.homelab-ca-bootstrap = {
      deps = [ "users" ];
      text = ''
        mkdir -p "${publicCaDir}"
        chmod 755 "${publicCaDir}"

        if [ -f "${caDir}/certs/root_ca.crt" ]; then
          # Always refresh the public copy in case it was wiped.
          cp "${caDir}/certs/root_ca.crt" "${publicCaDir}/root_ca.crt"
          chmod 644 "${publicCaDir}/root_ca.crt"
          exit 0
        fi

        echo "Bootstrapping homelab CA..."
        mkdir -p "${caDir}/certs" "${caDir}/secrets" "${caDir}/db"

        STEPPATH=$(mktemp -d)
        export STEPPATH

        ${pkgs.step-cli}/bin/step certificate create \
          "Homelab Root CA" \
          "${caDir}/certs/root_ca.crt" \
          "${caDir}/secrets/root_ca_key" \
          --profile root-ca \
          --no-password --insecure

        ${pkgs.step-cli}/bin/step certificate create \
          "Homelab Intermediate CA" \
          "${caDir}/certs/intermediate_ca.crt" \
          "${caDir}/secrets/intermediate_ca_key" \
          --profile intermediate-ca \
          --ca "${caDir}/certs/root_ca.crt" \
          --ca-key "${caDir}/secrets/root_ca_key" \
          --no-password --insecure

        rm -rf "$STEPPATH"

        chmod 700 "${caDir}/secrets"
        chmod 600 "${caDir}/secrets/"*
        chmod 755 "${caDir}/certs"
        chmod 644 "${caDir}/certs/"*
        chown -R step-ca:step-ca "${caDir}"

        cp "${caDir}/certs/root_ca.crt" "${publicCaDir}/root_ca.crt"
        chmod 644 "${publicCaDir}/root_ca.crt"

        echo "Homelab CA initialized. Root cert: ${caDir}/certs/root_ca.crt"
      '';
    };

    services.step-ca = {
      enable = true;
      address = "127.0.0.1";
      port = cfg.localCA.port;
      intermediatePasswordFile = null;
      settings = {
        root = "${caDir}/certs/root_ca.crt";
        federatedRoots = null;
        crt = "${caDir}/certs/intermediate_ca.crt";
        key = "${caDir}/secrets/intermediate_ca_key";
        dnsNames = [ "localhost" "127.0.0.1" ];
        logger.format = "text";
        db = {
          type = "badgerv2";
          dataSource = "${caDir}/db";
        };
        authority.provisioners = [
          {
            type = "ACME";
            name = "acme";
            # Issue 90-day certs to match Let's Encrypt; lego's default renewal threshold
            # is 30 days, so certs renew automatically before expiry.
            claims = {
              minTLSCertDuration = "24h";
              maxTLSCertDuration = "2160h";
              defaultTLSCertDuration = "2160h";
            };
          }
        ];
        tls = {
          cipherSuites = [
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
          ];
          minVersion = 1.2;
          maxVersion = 1.3;
          renegotiation = false;
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        server = "https://127.0.0.1:${toString cfg.localCA.port}/acme/acme/directory";
        email = "admin@homelab.lan";
        # step-ca listens on 127.0.0.1 only; skip TLS verification so lego can
        # connect without needing the local CA in the system trust store first.
        extraLegoFlags = [ "--tls-skip-verify" ];
      };
    };

    # Serve root cert over plain HTTP so any device can trust it without HTTPS.
    # Download from http://mini.lan/ca.crt and install as a trusted CA.
    services.nginx = lib.mkIf cfg.reverseProxy.enable {
      # Exact match avoids gixy alias_traversal false positive.
      # Alias points to publicCaDir (world-readable) — caDir is mode 700 (step-ca only).
      virtualHosts."mini.lan".locations."= /ca.crt" = {
        alias = "${publicCaDir}/root_ca.crt";
        extraConfig = ''
          add_header Content-Type application/x-x509-ca-cert;
          add_header Content-Disposition 'attachment; filename="homelab-ca.crt"';
          add_header Cache-Control "no-cache";
        '';
      };
    };
  })

  ]; # end mkMerge
}
