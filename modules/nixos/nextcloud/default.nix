{
  config,
  lib,
  ...
}:

let
  cfg = config.services.nextcloud;
  domain = config.networking.domain;
  subdomain = cfg.reverseProxy.subdomain;
  fqdn = if (cfg.reverseProxy.enable && subdomain != "") then "${subdomain}.${domain}" else domain;

  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkIf
    optionalAttrs
    ;

  inherit (lib.utils)
    mkMailIntegrationOption
    mkReverseProxyOption
    mkVirtualHost
    ;
in
{
  options.services.nextcloud = {
    mailIntegration = mkMailIntegrationOption "Nextcloud";
    reverseProxy = mkReverseProxyOption "Nextcloud" "nc";
    twoFactor = {
      enable = mkEnableOption "two-factor authentication via TOTP and backup codes";
      enforce = mkEnableOption "enforcing two-factor authentication for all users";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."secrets/nextcloud-initial-admin-pass".text = "nextcloud";

    services.nextcloud = {
      hostName = fqdn;
      https = if cfg.reverseProxy.enable then cfg.reverseProxy.forceSSL else mkDefault false;
      config = {
        adminuser = mkDefault "nextcloud";
        adminpassFile = mkDefault "/etc/secrets/nextcloud-initial-admin-pass";
        dbtype = mkDefault "pgsql";
      };
      database.createLocally = mkDefault true;
      configureRedis = mkDefault true;
      extraAppsEnable = mkDefault true;
      appstoreEnable = mkDefault false;
      webfinger = mkDefault true;
      settings = {
        log_type = mkDefault "systemd";
        loglevel = mkDefault 2;
        syslog_tag = mkDefault "Nextcloud";

        maintenance_window_start = 2;
        default_phone_region = mkDefault "DE";
      }
      // optionalAttrs cfg.mailIntegration.enable {
        mail_domain = mkDefault domain;
        mail_from_address = mkDefault "nextcloud";
        mail_smtpauth = mkDefault true;
        mail_smtphost = mkDefault cfg.mailIntegration.smtpHost;
        mail_smtpmode = mkDefault "smtp";
        mail_smtpname = mkDefault "nextcloud@${domain}";
        mail_smtpport = mkDefault 465;
        mail_smtpsecure = mkDefault "ssl";
        mail_smtptimeout = mkDefault 30;
      };
      phpOptions = {
        catch_workers_output = "yes";
        display_errors = "stderr";
        error_reporting = "E_ALL & ~E_DEPRECATED & ~E_STRICT";
        expose_php = "Off";
        "opcache.fast_shutdown" = "1";
        "opcache.interned_strings_buffer" = "64";
        "opcache.max_accelerated_files" = "10000";
        "opcache.memory_consumption" = "512";
        "opcache.revalidate_freq" = "1";
        output_buffering = "0";
        short_open_tag = "Off";
      };
      secretFile = mkIf cfg.mailIntegration.enable config.sops.templates."nextcloud".path;
    };

    systemd.services.nextcloud-twofactor = mkIf cfg.twoFactor.enable {
      after = [ "nextcloud-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecCondition = "${getExe cfg.occ} status --exit-code";
      };
      script = ''
        ${getExe cfg.occ} app:enable twofactor_totp twofactor_backupcodes
        ${getExe cfg.occ} twofactorauth:enforce ${if cfg.twoFactor.enforce then "--on" else "--off"}
      '';
    };

    services.nginx.virtualHosts = mkIf cfg.reverseProxy.enable {
      "${cfg.hostName}" = mkVirtualHost {
        inherit config fqdn;
        ssl = cfg.reverseProxy.forceSSL;
      };
    };

    sops = mkIf cfg.mailIntegration.enable (
      let
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0440";
      in
      {
        secrets."nextcloud/smtp-password" = {
          inherit owner group mode;
        };
        templates."nextcloud" = {
          inherit owner group mode;
          content = ''
            {"mail_smtppassword":"${config.sops.placeholder."nextcloud/smtp-password"}"}
          '';
        };
      }
    );
  };
}
