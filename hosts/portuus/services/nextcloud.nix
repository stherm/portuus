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

  package = pkgs.nextcloud35.overrideAttrs (old: rec {
    version = "35.0.2";
    src = pkgs.fetchurl {
      url = "https://download.nextcloud.com/server/releases/nextcloud-${version}.tar.bz2";
      hash = "sha256-38eVXq7FYh3pDgMdEPdgBhc7Pz4x1dbhdIIdHaFPFi0=";
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
    twoFactor = {
      enable = true;
      enforce = true;
      enforcedGroups = [ "admin" ];
    };
    theming = {
      name = "portuus";
      slogan = "Cloud auf portuus.de";
      url = "https://portuus.de";
      primary_color = "#4c8099";
      background = "backgroundColor";
      background_color = "#02192e";
      logo = ../../../assets/branding/logo.svg;
      logoheader = ../../../assets/branding/logo.svg;
      favicon = ../../../assets/branding/logo.svg;
    };
    settings = {
      trusted_proxies = [ c.hosts.edge.ip ];
      "overwrite.cli.url" = "https://${config.services.nextcloud.hostName}";
      serverid = 238;
    };
  };
}
