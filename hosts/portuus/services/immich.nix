{
  outputs,
  config,
  lib,
  pkgs,
  constants,
  ...
}:

let
  c = constants;
  s = c.services.immich;
in
{
  imports = [ outputs.nixosModules.immich ];

  services.immich = {
    enable = true;
    package = pkgs.unstable.immich;
    reverseProxy = {
      enable = true;
      inherit (s) subdomain;
      forceSSL = false;
    };
    settings.server.externalDomain = lib.mkForce "https://${s.fqdn}";
    mediaLocation = "/data/immich";
    accelerationDevices = null;
  };
}
