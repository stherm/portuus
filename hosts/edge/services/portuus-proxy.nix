{ lib, constants, ... }:

let
  c = constants;
  portuusIP = c.hosts.portuus.ip;
  s = c.services;

  mkProxy = subdomain: extraConfig: {
    "${subdomain}.${c.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${portuusIP}";
        inherit extraConfig;
      };
    };
  };
in
{
  services.nginx.virtualHosts = lib.mkMerge [
    (mkProxy s.nextcloud.subdomain "client_max_body_size 1G;")
    (mkProxy s.immich.subdomain "client_max_body_size 5G;")
    (mkProxy s.vaultwarden.subdomain "")
    (mkProxy s.radicale.subdomain "")
    (mkProxy s.jirafeau.subdomain "")

    {
      "${s.forgejo.fqdn}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${portuusIP}:${toString s.forgejo.port}";
          extraConfig = "client_max_body_size 0;";
        };
      };
    }

    {
      "${c.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/_matrix".proxyPass = "http://${portuusIP}";
          "/_synapse".proxyPass = "http://${portuusIP}";
          "^~ /_matrix/maubot/" = {
            proxyPass = "http://${portuusIP}";
            proxyWebsockets = true;
          };
          "= /.well-known/matrix/server".extraConfig = ''
            default_type application/json;
            return 200 '{"m.server":"${c.domain}:443"}';
          '';
          "= /.well-known/matrix/client".extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin "*";
            return 200 '${
              builtins.toJSON {
                "m.homeserver".base_url = "https://${c.domain}";
                "org.matrix.msc4143.rtc_foci" = [
                  {
                    type = "livekit";
                    livekit_service_url = "https://${c.domain}/livekit/jwt";
                  }
                ];
              }
            }';
          '';
        };
      };
    }
  ];
}
