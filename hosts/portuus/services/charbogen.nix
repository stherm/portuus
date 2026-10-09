{
  inputs,
  config,
  lib,
  constants,
  ...
}:

let
  c = constants.services.charbogen;
in
{
  imports = [ inputs.charbogen.nixosModules.default ];

  services.charbogen = {
    enable = true;
    domain = c.fqdn;
    inherit (c) port;

    bogen.enable = true;
    wiki.enable = true;
    api.enable = true;

    auth = {
      mode = "proxy";
      proxySecretFile = config.sops.secrets."charbogen/proxy-secret".path;
      webAdmin = true;
      adminGroup = "charbogen-admin";
      authelia = {
        domain = c.authFqdn;
        usersFile = "/data/charbogen/users.yml";
        secrets = {
          jwtSecretFile = config.sops.secrets."charbogen/authelia-jwt".path;
          sessionSecretFile = config.sops.secrets."charbogen/authelia-session".path;
          storageEncryptionKeyFile = config.sops.secrets."charbogen/authelia-storage".path;
        };
        smtp = {
          enable = true;
          address = "submissions://${config.mailserver.fqdn}:465";
          username = "noreply@${c.fqdn}";
          sender = "Charbogen <noreply@${c.fqdn}>";
          passwordFile = config.sops.secrets."charbogen/smtp-password".path;
          after = [
            "postfix.service"
            "dovecot.service"
          ];
        };
        settings.notifier.disable_startup_check = true;
      };
    };

    postgresql = {
      enable = false;
      provision = true;
    };

    nginx = {
      enableACME = false;
      forceSSL = false;
      listenAddresses = [ constants.hosts.portuus.ip ];
    };

    secretKeyFile = config.sops.secrets."charbogen/secret-key".path;
    dbCredentialsFile = "/data/charbogen/db_credentials.txt";
  };

  services.nginx.virtualHosts."${c.authFqdn}".locations."/" = {
    recommendedProxySettings = lib.mkForce false;
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-Host $host;
    '';
  };

  sops.secrets = {
    "charbogen/secret-key" = {
      owner = "charbogen";
      group = "charbogen";
      mode = "0400";
    };
    "charbogen/proxy-secret" = {
      owner = "charbogen";
      group = "charbogen";
      mode = "0400";
    };
    "charbogen/authelia-jwt" = {
      owner = "authelia-charbogen";
      mode = "0400";
    };
    "charbogen/authelia-session" = {
      owner = "authelia-charbogen";
      mode = "0400";
    };
    "charbogen/authelia-storage" = {
      owner = "authelia-charbogen";
      mode = "0400";
    };
    "charbogen/smtp-password" = {
      owner = "authelia-charbogen";
      mode = "0400";
      restartUnits = [ "authelia-charbogen.service" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/charbogen 0750 charbogen charbogen -"
    "f /data/charbogen/db_credentials.txt 0600 charbogen charbogen -"
  ];
}
