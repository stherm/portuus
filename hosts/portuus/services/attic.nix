{
  config,
  constants,
  lib,
  ...
}:

let
  s = constants.services.attic;
  cfg = config.services.atticd;
  storageDir = "/data/attic";
in
{
  services = {
    atticd = {
      enable = true;
      environmentFile = config.sops.templates."atticd/env".path;
      settings = {
        listen = "127.0.0.1:${toString s.port}";
        api-endpoint = "https://${s.fqdn}/";
        database.url = "postgresql:///atticd?host=/run/postgresql";
        storage = {
          type = "local";
          path = storageDir;
        };
        compression.type = "zstd";
        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "3 months";
        };
      };
    };

    postgresql = {
      ensureDatabases = [ "atticd" ];
      ensureUsers = [
        {
          name = "atticd";
          ensureDBOwnership = true;
        }
      ];
    };

    nginx.virtualHosts.${s.fqdn}.locations."/" = {
      proxyPass = "http://127.0.0.1:${toString s.port}";
      extraConfig = ''
        client_max_body_size 0;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  users = {
    users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
    };
    groups.${cfg.group} = { };
  };

  systemd = {
    tmpfiles.rules = [ "d ${storageDir} 0750 ${cfg.user} ${cfg.group} - -" ];

    services = {
      atticd-dirs = {
        description = "attic storage directory";
        requiredBy = [ "atticd.service" ];
        before = [ "atticd.service" ];
        unitConfig.RequiresMountsFor = [ storageDir ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${storageDir}";
        };
      };

      atticd = {
        unitConfig.RequiresMountsFor = [ storageDir ];
        serviceConfig.DynamicUser = lib.mkForce false;
      };
    };
  };

  sops = {
    secrets."atticd/server-token" = { };
    templates."atticd/env" = {
      content = ''
        ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."atticd/server-token"}
      '';
      restartUnits = [ "atticd.service" ];
    };
  };
}
