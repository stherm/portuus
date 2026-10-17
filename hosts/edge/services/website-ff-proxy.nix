{ constants, ... }:

let
  c = constants;
  inherit (c.services.feuerwehr) fqdn;
in
{
  services.nginx.virtualHosts = {
    ${fqdn} = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://${c.hosts.portuus.ip}";
    };
    "www.${fqdn}" = {
      enableACME = true;
      forceSSL = true;
      globalRedirect = fqdn;
    };
  };
}
