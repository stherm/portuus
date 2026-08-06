{ config, constants, ... }:

let
  c = constants;
in
{
  services = {
    livekit = {
      enable = true;
      openFirewall = true;
      keyFile = config.sops.templates."livekit/key".path;
      settings.port = 7880;
      settings.room.auto_create = false;
    };

    lk-jwt-service = {
      enable = true;
      port = 8090;
      livekitUrl = "wss://${c.domain}/livekit/sfu";
      keyFile = config.sops.templates."livekit/key".path;
    };

    nginx.virtualHosts."${c.domain}".locations = {
      "^~ /livekit/jwt/" = {
        priority = 400;
        proxyPass = "http://127.0.0.1:${toString config.services.lk-jwt-service.port}/";
      };
      "^~ /livekit/sfu/" = {
        priority = 400;
        proxyPass = "http://127.0.0.1:${toString config.services.livekit.settings.port}/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_send_timeout 120;
          proxy_read_timeout 120;
          proxy_buffering off;
          proxy_set_header Accept-Encoding gzip;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
  };

  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = c.domain;

  networking.firewall.allowedTCPPorts = [ 7881 ];

  sops = {
    secrets."livekit/key" = { };
    templates."livekit/key".content = ''
      lk-jwt-service: ${config.sops.placeholder."livekit/key"}
    '';
  };
}
