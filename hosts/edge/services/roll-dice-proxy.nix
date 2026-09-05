{ constants, ... }:

let
  c = constants;
in
{
  services.nginx.virtualHosts = {
    "${c.services.charbogen.fqdn}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${c.hosts.portuus.ip}";
        proxyWebsockets = true;
      };
    };
    "${c.services.charbogen.authFqdn}" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://${c.hosts.portuus.ip}";
    };
  };
}
