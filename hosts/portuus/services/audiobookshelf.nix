{
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  s = constants.services.audiobookshelf;
  cfg = config.services.audiobookshelf;
  b = constants.branding;
  css = pkgs.writeText "audiobookshelf-portuus.css" (
    b.cssVariables + builtins.readFile ../../../assets/branding/audiobookshelf.css
  );
  mediaDir = "/data/audiobooks";
in
{
  services = {
    audiobookshelf = {
      enable = true;
      inherit (s) port;
    };

    nginx.virtualHosts.${s.fqdn}.locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${toString s.port}";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 2G;
          sub_filter '</head>' '<link rel="stylesheet" href="/audiobookshelf/portuus.css"></head>';
          sub_filter_once on;
        '';
      };
      "= /audiobookshelf/icon.svg".alias = b.logo;
      "= /audiobookshelf/portuus.css".alias = css;
      "~ ^/audiobookshelf/_nuxt/img/icon\\.[0-9a-f]+\\.svg$" = {
        root = dirOf b.logo;
        extraConfig = "try_files /logo.svg =404;";
      };
    }
    // b.iconLocations { inherit lib pkgs; } {
      "audiobookshelf/favicon.ico" = 48;
      "audiobookshelf/ios_icon.png" = 180;
      "audiobookshelf/icon192.png" = 192;
    };
  };

  systemd = {
    tmpfiles.rules = [ "d ${mediaDir} 0750 ${cfg.user} ${cfg.group} - -" ];

    services = {
      audiobookshelf-dirs = {
        description = "Audiobookshelf media directory";
        requiredBy = [ "audiobookshelf.service" ];
        before = [ "audiobookshelf.service" ];
        unitConfig.RequiresMountsFor = [ mediaDir ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${mediaDir}";
        };
      };

      audiobookshelf.unitConfig.RequiresMountsFor = [ mediaDir ];
    };
  };
}
