{
  inputs,
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  s = c.services.radicale;
  b = c.branding;

  package = if config.services.radicale.package != null then config.services.radicale.package else pkgs.radicale;

  css = pkgs.runCommand "radicale-portuus-css" { } ''
    main=$(find ${package}/lib -path '*/radicale/web/internal_data/css/main.css' | head -n 1)
    cat "$main" ${pkgs.writeText "portuus-colors.css" b.cssVariables} ${../../../assets/branding/radicale.css} > $out
  '';
in
{
  imports = [ inputs.synix.nixosModules.radicale ];

  services.radicale = {
    enable = true;
    reverseProxy = {
      enable = true;
      inherit (s) subdomain;
      forceSSL = false;
    };
    users = [
      "pascal"
      "portuus"
      "susagi"
      "steffen"
      "ulm"
    ];
  };

  services.nginx.virtualHosts.${s.fqdn}.locations = {
    "= /.web/css/main.css".alias = css;
    "= /.web/css/logo.svg".alias = b.logo;
  }
  // b.iconLocations { inherit lib pkgs; } { ".web/css/icon.png" = 64; };
}
