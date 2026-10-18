{
  inputs,
  config,
  pkgs,
  lib,
  constants,
  ...
}:

{
  imports = [
    inputs.synix.nixosModules.matrix-synapse
    inputs.synix.nixosModules.maubot
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services = {
    matrix-synapse = {
      enable = true;
      sops = true;
      dataDir = "/data/matrix-synapse";
      settings.max_upload_size = "200M";
      bridges = {
        whatsapp = {
          enable = true;
          admin = "@steffen:portuus.de";
        };
        signal = {
          enable = true;
          admin = "@steffen:portuus.de";
        };
      };
    };

    maubot = {
      enable = true;
      sops = true;
      dataDir = "/data/maubot";
      admins = [
        "steffen"
      ];
      plugins = with config.services.maubot.package.plugins; [
        choose
        dice
        github
        karma
        poll
        reactbot
        reminder
        tex
        timein
        timer
        translate
        urban
        urlpreview
        weather
        webhook
        xkcd
      ];
    };

    livekit.enable = lib.mkForce false;
    lk-jwt-service.enable = lib.mkForce false;

    nginx.virtualHosts = {
      "matrix.tail" = {
        listen = [
          {
            addr = constants.hosts.portuus.ip;
            port = 80;
          }
        ];
        root = pkgs.ketesa.withConfig { restrictBaseUrl = "http://matrix.tail"; };
        locations = {
          "/_matrix".proxyPass = "http://127.0.0.1:${toString config.services.matrix-synapse.port}";
          "/_synapse".proxyPass = "http://127.0.0.1:${toString config.services.matrix-synapse.port}";
          "^~ /_matrix/maubot/" = {
            proxyPass = with config.services.maubot.settings.server; "http://${hostname}:${toString port}";
            proxyWebsockets = true;
          };
        };
      };

      "${config.networking.domain}" = {
        locations."/_matrix".extraConfig = "client_max_body_size 200M;";
        enableACME = lib.mkForce false;
        forceSSL = lib.mkForce false;
        listen = lib.mkForce [
          {
            addr = constants.hosts.portuus.ip;
            port = 80;
          }
        ];
      };
    };
  };

  systemd.services.lk-jwt-service.enable = false;
}
