{
  inputs,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  s = c.services.jirafeau;
  b = c.branding;
  col = b.colors;

  package = pkgs.jirafeau.overrideAttrs (old: {
    installPhase = old.installPhase + ''
      theme=$out/media/portuus
      cp -r $out/media/dark-courgette $theme
      chmod -R u+w $theme
      cp ${b.logo} $theme/logo-jirafeau.svg
      sed -i -E \
        -e 's/#212121\b/${col.navy}/gI' \
        -e 's/#7d7d7d\b/${col.blue-700}/gI' \
        -e 's/#e5e5e5\b/${col.blue-100}/gI' \
        -e 's/#555\b/${col.blue-600}/gI' \
        -e 's/#0d9cb2\b/${col.blue-400}/gI' \
        -e 's/#bcaaa4\b/${col.blue-600}/gI' \
        -e 's/#bbb\b/${col.muted}/gI' \
        $theme/style.css.php
      sed -i 's/#bcaaa4/${col.blue-600}/gI' $theme/upload.svg
    '';
  });
in
{
  imports = [ inputs.synix.nixosModules.jirafeau ];

  services.jirafeau = {
    enable = true;
    inherit package;
    dataDir = "/data/jirafeau";
    reverseProxy = {
      enable = true;
      inherit (s) subdomain;
      forceSSL = false;
    };
    extraConfig = ''
      $cfg['style'] = 'portuus';
      $cfg['dark_style'] = 'portuus';
      $cfg['title'] = 'portuus share';
      $cfg['organisation'] = 'portuus';
      $cfg['maximal_upload_size'] = 4096;
    '';
  };

  services.nginx.virtualHosts.${s.fqdn}.locations = b.iconLocations { inherit lib pkgs; } {
    "media/portuus/favicon.ico" = 48;
  };
}
