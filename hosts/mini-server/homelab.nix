# ~/nixos-config/hosts/mini-server/homelab.nix
{ config, pkgs, lib, unstablePkgs, ... }:

{
  customConfig.homelab = {
    nasClient = {
      enable = true;
      # NAS is on this same server subnet post-migration; mount Samba directly
      # rather than via the firewall's legacy 192.168.1.76 alias (which doesn't
      # forward 445/139). Traffic stays within the trusted server segment.
      serverAddress = "192.168.100.76";
    };

    # Reach the NAS nix binary cache directly on the server subnet (the legacy
    # 192.168.1.76 alias isn't reachable from behind the firewall).
    nixCache.clientHost = "192.168.100.76";

    vaultwarden.enable = true;

    homeAssistant = {
      enable = true;
      # Stays on unstable, and this is a FLOOR, not a preference — do not "clean it
      # up" onto stable just because stable's version looks new enough.
      #
      # Home Assistant migrates files under ~/.storage forward on first run by a newer
      # release, and never migrates them back. An older build then refuses to start:
      #   UnsupportedStorageVersionError: Storage file http has version 2 which is
      #   newer than the max supported version 1
      #
      # That is exactly what the 26.05 upgrade hit. The previous comment justified
      # unstable *only* by a backup feature needing >= 2026.2.1, so when 26.05 shipped
      # 2026.5.4 the override looked obsolete and was dropped. But this host had been
      # running unstable's 2026.9.3, which had already taken .storage/http to version 2,
      # and stable 2026.5.4 crash-looped on every start.
      #
      # Same shape as the signal-desktop version floor in unstable-overlay.nix: on-disk
      # state only moves forward, so the package must never move backwards. Only move to
      # stable once stable's HA is >= whatever last wrote this host's .storage.
      package = unstablePkgs.home-assistant;
    };

    wyoming = {
      enable = true;
      satellite.name = "mini-server";
      # Reference cards by ALSA card *name* (stable) rather than numeric index —
      # USB re-enumeration on reboot has swapped card 0/1 twice now.
      # MIC = Generalplus USB mic, PCH = onboard HDA Intel (analog line-out).
      satellite.micDevice = "plughw:MIC,0";
      satellite.sndDevice = "plughw:PCH,0";
      satellite.awakeWav = "${../../modules/nixos/homelab/wyoming-sounds/awake.wav}";
      satellite.doneWav = "${../../modules/nixos/homelab/wyoming-sounds/done.wav}";
      # ok_nabu is a more robust openWakeWord model than hey_jarvis and handles most
      # false-trigger rejection on its own; WebRTC noise suppression covers TV/background,
      # and threshold/trigger-level are kept near defaults for good far-field response.
      satellite.wakeWord = "ok_nabu";
      satellite.noiseSuppression = 2;
      satellite.autoGain = 0;
      openwakeword.threshold = 0.6;
      openwakeword.triggerLevel = 1;
      whisper.model = "small-int8";
      whisper.language = "en";
      piper.voice = "en_US-lessac-medium";
    };

    gameServers = {
      astroneer.enable = true;
      minecraftSurvival.enable = true;
      minecraftMinigames.enable = true;
      minecraftBedrock.enable = true;
      minecraftBedrockLandon.enable = true;
      minecraftBedrockVenator.enable = true;
      bedrockAllowList = [
        "GreenArroww9090:2535408372064922"
      ];
    };

    gameControl.enable = true;

    browserPuck.enable = true;

    # R62D (insideabush's 5v5 browser game) for every VPN player: http://192.168.1.76:6262
    r62d.enable = false;

    # Our own git server (prin-rpg): http://192.168.1.76:3000, docs/forgejo.md
    forgejo.enable = true;

    gameBackup.enable = true;
    # Offsite copy to atl-mini-pc (mom's). Flip once her VPN and rest-server are up:
    # docs/hosts/atl-mini-pc.md, "Offsite backup".
    gameBackup.offsite.enable = false;

    localCA.enable = true;
    localCA.trustCA = true;

    reverseProxy.enable = true;
  };

  # State dirs for game-control watchdog idle timers and game server volumes
  systemd.tmpfiles.rules = [
    "d /var/lib/game-control 0755 root root - -"
    "d /var/lib/game-servers 0755 root root - -"
  ];

  # Version-control HA config files alongside this host config.
  # The NixOS HA module manages configuration.yaml the same way.
  environment.etc."home-assistant/automations.yaml".source = ./home-assistant/automations.yaml;
  environment.etc."home-assistant/custom_sentences/en/weather.yaml".source =
    ./home-assistant/custom_sentences/en/weather.yaml;
  systemd.services.home-assistant.preStart = lib.mkAfter ''
    ln -sf /etc/home-assistant/automations.yaml /var/lib/hass/automations.yaml
    mkdir -p /var/lib/hass/custom_sentences/en
    ln -sf /etc/home-assistant/custom_sentences/en/weather.yaml /var/lib/hass/custom_sentences/en/weather.yaml
  '';

  # Voice forecasts from the National Weather Service. The NWS integration has no YAML
  # setup: add it once in the UI (any email as the API key) and type KSTL as the station.
  # NWS auto-picks KCPS (Cahokia), which drops half its hourly readings, so the current
  # temperature went stale. The entity id still ends in _kcps: HA keys it by home
  # coordinates only and restored the first id when the entry was re-added on KSTL.
  #
  # Two paths reach the forecast:
  #  - intent_script.WeatherForecast answers the custom sentences in
  #    home-assistant/custom_sentences/en/weather.yaml locally, so "what's the weather
  #    today" works even when the Google AI entry failed setup.
  #  - script.weather_forecast is the tool Gemini calls for anything else ("will it
  #    rain tomorrow?"). It must be exposed to Assist in the UI to be callable.
  services.home-assistant.config =
    let
      weather = "weather.nws_38_595803_90_2206566_kcps";

      # weather.get_forecasts carries the numbers (temperature, precipitation_probability,
      # is_daytime) but not NWS's wording; nws.get_forecasts_extra carries only the wording
      # (short_description "Sunny", detailed_description). Both come from the same NWS
      # period list, so merge them index by index into `forecast`.
      getForecast = type: [
        {
          action = "weather.get_forecasts";
          target.entity_id = weather;
          data.type = type;
          response_variable = "fc";
        }
        {
          action = "nws.get_forecasts_extra";
          target.entity_id = weather;
          data.type = type;
          response_variable = "fx";
        }
        {
          variables.forecast = ''
            {%- set p = fc['${weather}'].forecast -%}
            {%- set x = fx['${weather}'].forecast -%}
            {%- set ns = namespace(out=[]) -%}
            {%- for i in range(p | count) -%}
              {%- set ns.out = ns.out + [dict(p[i], **(x[i] if x | count > i else {}))] -%}
            {%- endfor -%}
            {{ ns.out }}
          '';
        }
      ];
    in
    {
      intent_script.WeatherForecast = {
        # Action-local variables don't reach the speech template; only the sequence's
        # own response does, as `action_response`, so stop with the forecast as it.
        action = getForecast "twice_daily" ++ [
          { variables.result.forecast = "{{ forecast }}"; }
          { stop = ""; response_variable = "result"; }
        ];
        # twice_daily periods alternate day/night; the first one is whatever period
        # we are in now, so after ~6 PM it is "tonight".
        speech.text = ''
          {%- set p = action_response.forecast -%}
          {%- set cur = state_attr('${weather}', 'temperature') -%}
          {%- macro rain(x) -%}
            {%- if (x.precipitation_probability or 0) >= 10 %} {{ x.precipitation_probability }} percent chance of rain.{% endif -%}
          {%- endmacro -%}
          {%- macro desc(x) -%}
            {{ x.short_description or (x.condition or "") | replace("partlycloudy", "partly cloudy") }}
          {%- endmacro -%}
          {%- if p | count == 0 -%}
            Sorry, I couldn't get the forecast right now.
          {%- elif p[0].is_daytime -%}
            Today: {{ desc(p[0]) }}. High of {{ p[0].temperature | round }}
            {%- if p | count > 1 %}, low of {{ p[1].temperature | round }}{% endif %}.
            {{- rain(p[0]) }}
            {%- if cur is number %} It's {{ cur | round }} degrees right now.{% endif %}
          {%- else -%}
            Tonight: {{ desc(p[0]) }}. Low of {{ p[0].temperature | round }}.
            {{- rain(p[0]) }}
            {%- if p | count > 1 %} Tomorrow: {{ desc(p[1]) }}, high of {{ p[1].temperature | round }}.{% endif %}
          {%- endif -%}
        '';
      };

      script.weather_forecast = {
        alias = "Weather forecast";
        description = ''
          Get the weather forecast from the National Weather Service: highs, lows,
          conditions, NWS's written forecast and percent chance of rain. Use this for any
          question about the weather today, tonight, tomorrow or later this week.
          "twice_daily" gives day/night periods for about a week; "hourly" gives the
          next hours.
        '';
        fields.type = {
          description = "Forecast resolution: twice_daily (default) or hourly.";
          example = "twice_daily";
          selector.select.options = [ "twice_daily" "hourly" ];
        };
        sequence = getForecast "{{ type | default('twice_daily') }}" ++ [
          # Hourly is ~150 entries; trim to the next 12 hours to keep the LLM context small.
          {
            variables.result.forecast = "{{ forecast[:12] if type | default('twice_daily') == 'hourly' else forecast }}";
          }
          { stop = "Forecast retrieved"; response_variable = "result"; }
        ];
      };
    };
}
