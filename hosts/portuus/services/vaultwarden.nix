{
  outputs,
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  s = c.services.vaultwarden;
  b = c.branding;

  templates = pkgs.writeTextDir "scss/user.vaultwarden.scss.hbs" (
    b.cssVariables + builtins.readFile ../../../assets/branding/vaultwarden.css
  );

  icons = {
    "favicon.ico" = 48;
    "images/favicon-16x16.png" = 16;
    "images/favicon-32x32.png" = 32;
    "images/apple-touch-icon.png" = 180;
    "images/android-chrome-192x192.png" = 192;
    "images/android-chrome-512x512.png" = 512;
    "images/mstile-150x150.png" = 150;
  };
in
{
  imports = [ outputs.nixosModules.vaultwarden ];

  services.vaultwarden = {
    enable = true;
    reverseProxy = {
      enable = true;
      inherit (s) subdomain;
      forceSSL = false;
    };
    config = {
      DOMAIN = "https://${s.fqdn}";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";
      TEMPLATES_FOLDER = "${templates}";
    };
    mailIntegration = {
      enable = true;
      smtpHost = config.mailserver.fqdn;
    };
    backupDir = "/data/backup/vaultwarden";
  };

  services.nginx.virtualHosts.${s.fqdn} = {
    extraConfig = ''
      set_real_ip_from ${c.hosts.edge.ip};
      real_ip_header X-Real-IP;
    '';
    locations = {
      "= /images/icon-white.svg".alias = b.logo;
    }
    // b.iconLocations { inherit lib pkgs; } (
      icons
      // lib.mapAttrs' (file: lib.nameValuePair (builtins.replaceStrings [ "images/" ] [ "images/icons/" ] file)) (
        lib.filterAttrs (file: _: lib.hasPrefix "images/" file) icons
      )
    );
  };

  systemd.services.backup-vaultwarden.unitConfig.RequiresMountsFor = [ config.services.vaultwarden.backupDir ];
}
