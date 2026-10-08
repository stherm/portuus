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

  branding = pkgs.runCommand "forgejo-portuus-branding" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    img=$out/public/assets/img
    mkdir -p $img $out/public/assets/css $out/templates

    cp ${./branding/logo.svg} $img/logo.svg
    cp ${./branding/favicon.svg} $img/favicon.svg
    rsvg-convert -w 512 -h 512 ${./branding/logo.svg} -o $img/logo.png
    rsvg-convert -w 180 -h 180 ${./branding/logo.svg} -o $img/apple-touch-icon.png
    rsvg-convert -w 180 -h 180 ${./branding/logo.svg} -o $img/avatar_default.png
    rsvg-convert -w 64 -h 64 ${./branding/favicon.svg} -o $img/favicon.png

    cp ${./branding/theme-portuus.css} $out/public/assets/css/theme-portuus.css
    cp ${./branding/home.tmpl} $out/templates/home.tmpl
  '';
in
{
  imports = [
    outputs.nixosModules.forgejo
  ];

  services.forgejo = {
    enable = true;
    stateDir = "/data/forgejo";
    settings = {
      DEFAULT.APP_NAME = "portuus Git";
      server = {
        DOMAIN = fj.testFqdn;
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
    };
  };

  systemd.tmpfiles.rules = [
    "L+ ${cfg.customDir}/public - - - - ${branding}/public"
    "L+ ${cfg.customDir}/templates - - - - ${branding}/templates"
  ];

  systemd.services.forgejo.restartTriggers = [ branding ];
}
