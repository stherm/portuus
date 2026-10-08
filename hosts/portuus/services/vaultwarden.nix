{
  outputs,
  config,
  constants,
  ...
}:

let
  c = constants;
  s = c.services.vaultwarden;
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
    };
    mailIntegration = {
      enable = true;
      smtpHost = config.mailserver.fqdn;
    };
  };
}
