{
  inputs,
  lib,
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
}
