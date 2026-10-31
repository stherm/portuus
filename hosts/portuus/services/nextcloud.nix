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
      primary_color = c.branding.primary;
      background = "backgroundColor";
      background_color = c.branding.colors.navy;
      logo = c.branding.logo;
      logoheader = c.branding.logo;
      favicon = c.branding.logo;
    };
    settings = {
      trusted_proxies = [ c.hosts.edge.ip ];
      "overwrite.cli.url" = "https://${config.services.nextcloud.hostName}";
      serverid = 238;
    };
  };
}
