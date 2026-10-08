{
  config,
  lib,
  ...
}:

let
  cfg = config.services.forgejo;

  inherit (cfg) settings;
  inherit (lib)
    getExe
    head
    mkDefault
    mkIf
    ;
in
{
  config = mkIf cfg.enable {
    services.forgejo = {
      database.type = mkDefault "postgres";
      lfs.enable = mkDefault true;
      settings = {
        lfs = {
          STORAGE_TYPE = mkDefault "local";
        };
        server = {
          DOMAIN = mkDefault "git.${config.networking.domain}";
          PROTOCOL = mkDefault "http";
          ROOT_URL = mkDefault "https://${settings.server.DOMAIN}/";
          HTTP_ADDR = mkDefault "0.0.0.0";
          HTTP_PORT = mkDefault 3456;
          SSH_PORT = mkDefault (head config.services.openssh.ports);
        };
        service = {
          DISABLE_REGISTRATION = mkDefault true;
        };
        ui = {
          DEFAULT_THEME = mkDefault "forgejo-dark";
        };
        actions = {
          ENABLED = mkDefault true;
          RETENTION_DAYS = mkDefault 30;
        };
        mailer = {
          ENABLED = mkDefault false;
          SMTP_ADDR = mkDefault "mail.${config.networking.domain}";
          FROM = mkDefault "git@${settings.server.DOMAIN}";
          USER = mkDefault "git@${settings.server.DOMAIN}";
        };
      };
      secrets = {
        mailer.PASSWD = mkIf settings.mailer.ENABLED config.sops.secrets."forgejo/mail-pw".path;
      };
    };

    environment.shellAliases = {
      forgejo = "sudo -u ${cfg.user} ${getExe cfg.package} --config ${cfg.stateDir}/custom/conf/app.ini";
    };

    sops.secrets."forgejo/mail-pw" = mkIf settings.mailer.ENABLED {
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
    };
  };
}
