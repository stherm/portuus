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
      settings = {
        max_upload_size = "200M";
        max_event_delay_duration = "24h";
        rc_delayed_event_mgmt = {
          per_second = 1;
          burst_count = 20;
        };
      };
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
        extraConfig = ''
          deny ${constants.hosts.edge.ip};
          allow 100.64.0.0/10;
          allow fd7a:115c:a1e0::/48;
          deny all;
        '';
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

  systemd.services = {
    lk-jwt-service.enable = false;

    postgresql-synapse-nopass = {
      description = "Remove the default password of the matrix-synapse database role";
      after = [ "postgresql.target" ];
      requires = [ "postgresql.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };
      script = ''
        ${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -c 'ALTER ROLE "matrix-synapse" PASSWORD NULL'
      '';
    };
  };
}
