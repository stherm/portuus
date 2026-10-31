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

  icons = pkgs.runCommand "immich-portuus-icons" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir $out
    src=${b.png}/logo-1024.png
    for size in 16 32 48 96 144; do
      magick $src -resize ''${size}x$size $out/favicon-$size.png
    done
    magick $src -resize 64x64 $out/favicon.png
    magick $src -resize 180x180 $out/apple-icon-180.png
    magick $src -define icon:auto-resize=16,32,48 $out/favicon.ico
    for size in 192 512; do
      inner=$((size * 4 / 5))
      magick $src -resize ''${inner}x$inner -background '${b.colors.navy}' -gravity center -extent ''${size}x$size \
        $out/manifest-icon-$size.maskable.png
    done
  '';

  iconFiles = [
    "favicon.ico"
    "favicon.png"
    "favicon-16.png"
    "favicon-32.png"
    "favicon-48.png"
    "favicon-96.png"
    "favicon-144.png"
    "apple-icon-180.png"
    "manifest-icon-192.maskable.png"
    "manifest-icon-512.maskable.png"
  ];
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

  services.nginx.virtualHosts.${s.fqdn}.locations = lib.genAttrs (map (name: "= /${name}") iconFiles) (location: {
    alias = "${icons}/${lib.removePrefix "= /" location}";
    extraConfig = ''
      add_header Cache-Control "public, max-age=86400";
    '';
  });
}
