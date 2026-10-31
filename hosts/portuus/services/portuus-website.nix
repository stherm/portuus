{
  inputs,
  config,
  pkgs,
  constants,
  ...
}:

let
  c = constants;
  s = c.services;
  site = inputs.portuus-website.packages.${pkgs.stdenv.hostPlatform.system}.default;
  minecraftUnit = name: [ "minecraft-server-${name}.service" ];
in
{
  imports = [ inputs.portuus-website.nixosModules.status ];

  services.nginx.virtualHosts.${config.networking.domain} = {
    root = site;
    extraConfig = "error_page 404 /404.html;";
    locations = {
      "/".tryFiles = "$uri $uri/index.html =404";
      "/_astro/".extraConfig = ''
        add_header Cache-Control "public, max-age=31536000, immutable";
      '';
    };
  };

  services.portuus-website-status = {
    enable = true;
    virtualHost = config.networking.domain;
    checks = {
      cloud.url = "https://${s.nextcloud.fqdn}/status.php";
      gallery.url = "https://${s.immich.fqdn}/api/server/ping";
      vault.url = "https://${s.vaultwarden.fqdn}/alive";
      dav.url = "https://${s.radicale.fqdn}/";
      mail.units = [
        "postfix.service"
        "dovecot.service"
      ];
      chat.url = "https://${s.matrix-synapse.fqdn}/_matrix/client/versions";
      share.url = "https://${s.jirafeau.fqdn}/";
      git.url = "https://${s.forgejo.fqdn}/api/healthz";
      vpn.url = "https://${s.headscale.fqdn}/health";
      rustdesk.units = [
        "rustdesk-signal.service"
        "rustdesk-relay.service"
      ];
      cache.units = [ "atticd.service" ];
      charbogen.url = "https://${s.charbogen.fqdn}/";
      feuerwehr.url = "https://${s.feuerwehr.fqdn}/";
      cobbleverse.units = minecraftUnit "cobbleverse";
      ttt.units = [ "gmod.service" ];
      survival.units = minecraftUnit "survival";
      creative.units = minecraftUnit "creative";
      amplified.units = minecraftUnit "amplified";
      palworld.units = [ "palworld.service" ];
    };
  };
}
