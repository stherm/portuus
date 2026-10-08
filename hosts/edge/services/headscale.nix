{
  inputs,
  lib,
  constants,
  ...
}:

{
  imports = [
    inputs.synix.nixosModules.headscale
  ];

  services.headscale = {
    enable = true;
    openFirewall = true;
    reverseProxy = {
      enable = true;
      subdomain = "hs";
    };
  };

  environment.etc."headscale/acl.hujson".source = lib.mkForce ./acl.hujson;

  networking.hosts."127.0.0.1" = [ constants.services.headscale.fqdn ];

  systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = "5min";
}
