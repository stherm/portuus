{
  inputs,
  config,
  pkgs,
  constants,
  ...
}:

let
  c = constants.services.feuerwehr;
  site = inputs.website-ff.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    inputs.website-ff.nixosModules.instagram
    inputs.website-ff.nixosModules.einsatzzahlen
  ];

  services = {
    nginx.virtualHosts.${c.fqdn} = {
      root = site;
      extraConfig = "error_page 404 /404.html;";
      locations = {
        "/".tryFiles = "$uri $uri/index.html =404";
        "/_astro/".extraConfig = ''
          add_header Cache-Control "public, max-age=31536000, immutable";
        '';
        "~ \\.pmtiles$".extraConfig = ''
          types { application/vnd.pmtiles pmtiles; }
        '';
      };
    };

    website-ff-instagram = {
      enable = true;
      tokenFile = config.sops.secrets."website-ff/instagram-token".path;
      virtualHost = c.fqdn;
    };

    website-ff-einsatzzahlen = {
      enable = true;
      url = "https://${constants.services.nextcloud.fqdn}/s/JzSD5QTG8y9JDgW/download";
      virtualHost = c.fqdn;
    };
  };

  sops.secrets."website-ff/instagram-token" = { };
}
