{
  inputs,
  pkgs,
  constants,
  ...
}:

let
  c = constants.services.feuerwehr;
  site = inputs.website-ff.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.nginx.virtualHosts.${c.fqdn} = {
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
}
