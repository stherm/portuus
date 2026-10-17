{
  outputs,
  config,
  pkgs,
  lib,
  constants,
  ...
}:

let
  c = constants;
  s = c.services.nextcloud;

  package = pkgs.nextcloud34.overrideAttrs (old: rec {
    version = "34.0.5";
    src = pkgs.fetchurl {
      url = "https://download.nextcloud.com/server/releases/nextcloud-${version}.tar.bz2";
      hash = "sha256-BOw93fRlyfLCqebuXzm4GDmdTz1YFVb0HQhyvutZsKk=";
    };
  });
in
{
  imports = [ outputs.nixosModules.nextcloud ];

  services.nextcloud = {
    enable = true;
    inherit package;
    datadir = "/data/nextcloud";
    reverseProxy = {
      enable = true;
      inherit (s) subdomain;
      forceSSL = false;
    };
    https = lib.mkForce true;
    mailIntegration = {
      enable = true;
      smtpHost = config.mailserver.fqdn;
    };
    twoFactor.enable = true;
  };
}
