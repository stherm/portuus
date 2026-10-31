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
    concatMapStrings
    concatStrings
    escapeShellArg
    escapeShellArgs
    getExe
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    optionalAttrs
    optionalString
    types
    ;

  occ = getExe cfg.occ;

  mkOccUnit = script: {
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      LoadCredential = config.systemd.services.nextcloud-cron.serviceConfig.LoadCredential;
      ExecCondition = "${occ} status --exit-code";
    };
    inherit script;
  };

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
      enforce = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether to enforce two-factor authentication. Null leaves the current policy untouched.";
      };
      enforcedGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "admin" ];
        description = "Groups for which two-factor authentication is enforced when enforce is true. Empty means all users.";
      };
    };
    disabledApps = mkOption {
      type = types.listOf types.str;
      default = optional (cfg.settings.log_type != "file") "logreader";
      description = "Shipped apps to disable via occ.";
    };
    theming = mkOption {
      type = types.attrsOf (types.either types.str types.path);
      default = { };
      example = {
        name = "portuus";
        primary_color = "#4c8099";
      };
      description = "Values applied via occ theming:config. The keys logo, logoheader, favicon and background take file paths.";
    };
  };

  config = mkIf cfg.enable {
    services.nextcloud = {
      hostName = fqdn;
      https = if cfg.reverseProxy.enable then cfg.reverseProxy.forceSSL else mkDefault false;
      config = {
        adminuser = mkDefault "nextcloud";
        adminpassFile = mkDefault config.sops.secrets."nextcloud/admin-pass".path;
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

    systemd.services = {
      nextcloud-dirs = {
        description = "Nextcloud data directories";
        requiredBy = [
          "nextcloud-setup.service"
          "phpfpm-nextcloud.service"
        ];
        before = [
          "nextcloud-setup.service"
          "phpfpm-nextcloud.service"
        ];
        unitConfig.RequiresMountsFor = [ cfg.datadir ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${cfg.datadir}";
        };
      };

      nextcloud-setup.unitConfig.RequiresMountsFor = [ cfg.datadir ];
      phpfpm-nextcloud.unitConfig.RequiresMountsFor = [ cfg.datadir ];

      nextcloud-twofactor = mkIf cfg.twoFactor.enable (mkOccUnit ''
        ${occ} app:enable twofactor_totp twofactor_backupcodes
        ${optionalString (cfg.twoFactor.enforce != null) (
          if cfg.twoFactor.enforce then
            "${occ} twofactorauth:enforce --on${concatMapStrings (g: " --group=${escapeShellArg g}") cfg.twoFactor.enforcedGroups}"
          else
            "${occ} twofactorauth:enforce --off"
        )}
      '');

      nextcloud-disable-apps = mkIf (cfg.disabledApps != [ ]) (mkOccUnit ''
        ${occ} app:disable ${escapeShellArgs cfg.disabledApps}
      '');

      nextcloud-theming = mkIf (cfg.theming != { }) (
        mkOccUnit (
          concatStrings (
            mapAttrsToList (k: v: "${occ} theming:config ${escapeShellArg k} ${escapeShellArg "${v}"}\n") cfg.theming
          )
        )
      );
    };

    services.nginx.virtualHosts = mkIf cfg.reverseProxy.enable {
      "${cfg.hostName}" = mkVirtualHost {
        inherit config fqdn;
        ssl = cfg.reverseProxy.forceSSL;
      };
    };

    sops =
      let
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0440";
      in
      mkMerge [
        {
          secrets."nextcloud/admin-pass" = {
            inherit owner group mode;
          };
        }
        (mkIf cfg.mailIntegration.enable {
          secrets."nextcloud/smtp-password" = {
            inherit owner group mode;
          };
          templates."nextcloud" = {
            inherit owner group mode;
            content = ''
              {"mail_smtppassword":"${config.sops.placeholder."nextcloud/smtp-password"}"}
            '';
          };
        })
      ];
  };
}
