{
  config,
  constants,
  ...
}:

let
  s = constants.services.audiobookshelf;
  cfg = config.services.audiobookshelf;
  mediaDir = "/data/audiobooks";
in
{
  services = {
    audiobookshelf = {
      enable = true;
      inherit (s) port;
    };

    nginx.virtualHosts.${s.fqdn}.locations."/" = {
      proxyPass = "http://127.0.0.1:${toString s.port}";
      proxyWebsockets = true;
      extraConfig = "client_max_body_size 2G;";
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
