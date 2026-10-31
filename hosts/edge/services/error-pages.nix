{
  lib,
  pkgs,
  constants,
  ...
}:

let
  c = constants;
  s = c.services;
  b = c.branding;

  errorPage = pkgs.runCommand "portuus-error-page" { } ''
    mkdir $out
    cp ${b.errorPage} $out/error.html
    chmod u+w $out/error.html
    substituteInPlace $out/error.html \
      --replace-fail @colors@ "$(cat ${pkgs.writeText "portuus-colors.css" b.cssVariables})" \
      --replace-fail @logo@ "$(cat ${b.logo})"
  '';

  vhosts = [
    c.domain
    s.attic.fqdn
    s.forgejo.fqdn
    s.headscale.fqdn
    s.immich.fqdn
    s.jirafeau.fqdn
    s.nextcloud.fqdn
    s.radicale.fqdn
    s.vaultwarden.fqdn
  ];

  webUis = [
    s.forgejo.fqdn
    s.immich.fqdn
    s.jirafeau.fqdn
    s.nextcloud.fqdn
    s.radicale.fqdn
    s.vaultwarden.fqdn
  ];
in
{
  services.nginx.virtualHosts = lib.genAttrs vhosts (vhost: {
    extraConfig = ''
      error_page 502 503 504 /_portuus/error.html;
    ''
    + lib.optionalString (lib.elem vhost webUis) ''
      proxy_intercept_errors on;
    '';
    locations."= /_portuus/error.html" = {
      alias = "${errorPage}/error.html";
      extraConfig = "internal;";
    };
  });
}
