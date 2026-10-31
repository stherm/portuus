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

  b = c.branding;
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
    settings = {
      server = {
        externalDomain = lib.mkForce "https://${s.fqdn}";
        loginPageMessage = "Welcome to the portuus gallery. Accounts are handed out by the admins.";
      };
      theme.customCss = b.cssVariables + builtins.readFile ../../../assets/branding/immich.css;
    };
    mediaLocation = "/data/immich";
    accelerationDevices = null;
  };

  services.nginx.virtualHosts.${s.fqdn}.locations = b.iconLocations { inherit lib pkgs; } {
    "favicon.ico" = 48;
    "favicon.png" = 64;
    "favicon-16.png" = 16;
    "favicon-32.png" = 32;
    "favicon-48.png" = 48;
    "favicon-96.png" = 96;
    "favicon-144.png" = 144;
    "apple-icon-180.png" = 180;
    "manifest-icon-192.maskable.png" = 192;
    "manifest-icon-512.maskable.png" = 512;
  };
}
