{
  outputs,
  config,
  constants,
  pkgs,
  ...
}:

let
  c = constants;
  fj = c.services.forgejo;
  cfg = config.services.forgejo;

  b = c.branding;
  colorsCss = pkgs.writeText "portuus-colors.css" b.cssVariables;

  branding = pkgs.runCommand "forgejo-portuus-branding" { } ''
    img=$out/public/assets/img
    mkdir -p $img $out/public/assets/css $out/templates

    cp ${b.logo} $img/logo.svg
    cp ${b.logo} $img/favicon.svg
    cp ${b.png}/logo-512.png $img/logo.png
    cp ${b.png}/logo-180.png $img/apple-touch-icon.png
    cp ${b.png}/logo-64.png $img/favicon.png

    theme=${./branding/theme-portuus.css}
    { head -n 1 $theme; echo; cat ${colorsCss}; tail -n +2 $theme; } > $out/public/assets/css/theme-portuus.css
    cp ${./branding/home.tmpl} $out/templates/home.tmpl
  '';
in
{
  imports = [
    outputs.nixosModules.forgejo
    ./runner.nix
  ];

  services.forgejo = {
    enable = true;
    stateDir = "/data/forgejo";
    settings = {
      DEFAULT.APP_NAME = "portuus Git";
      server = {
        DOMAIN = fj.fqdn;
        HTTP_PORT = fj.port;
        SSH_DOMAIN = fj.fqdn;
        SSH_PORT = fj.sshPort;
      };
      ui = {
        THEMES = "portuus,forgejo-auto,forgejo-light,forgejo-dark";
        DEFAULT_THEME = "portuus";
      };
      "ui.meta" = {
        AUTHOR = "portuus";
        DESCRIPTION = "Git-Hosting auf portuus.de";
      };
      repository = {
        DEFAULT_BRANCH = "main";
      };
      session.COOKIE_SECURE = true;
      actions.ENDLESS_TASK_TIMEOUT = "12h";
      api.ENABLE_SWAGGER = false;
      "service.explore".DISABLE_USERS_PAGE = true;
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtps";
        SMTP_PORT = 465;
        FROM = "\"portuus Git\" <git@${c.domain}>";
        USER = "git@${c.domain}";
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "L+ ${cfg.customDir}/public - - - - ${branding}/public"
      "L+ ${cfg.customDir}/templates - - - - ${branding}/templates"
    ];

    services = {
      forgejo-dirs = {
        description = "Forgejo state directories";
        requiredBy = [
          "forgejo-secrets.service"
          "forgejo.service"
        ];
        before = [
          "forgejo-secrets.service"
          "forgejo.service"
        ];
        unitConfig.RequiresMountsFor = [ cfg.stateDir ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${cfg.stateDir}";
        };
      };

      forgejo-secrets.unitConfig.RequiresMountsFor = [ cfg.stateDir ];

      forgejo = {
        unitConfig.RequiresMountsFor = [ cfg.stateDir ];
        restartTriggers = [ branding ];
      };
    };
  };
}
