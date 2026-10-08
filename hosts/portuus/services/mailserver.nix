{
  inputs,
  lib,
  config,
  constants,
  ...
}:

let
  c = constants;
  mp = c.mail-proxy;
  dataDir = "/data/mail";
  edgeIp = c.hosts.edge.ip;
  master = config.services.postfix.settings.master;
  proxyArgs = [
    "-o"
    "smtpd_upstream_proxy_protocol=haproxy"
  ];
  mkProxyListener = args: {
    type = "inet";
    private = false;
    command = "smtpd";
    args = args ++ proxyArgs;
  };
in
{
  imports = [ inputs.synix.nixosModules.mailserver ];

  mailserver = {
    enable = true;
    stateVersion = 3;
    openFirewall = false;
    storage.path = "${dataDir}/vmail";
    dkim = {
      keyDirectory = "${dataDir}/dkim";
      domains.${c.domain}.selectors = {
        mail2026 = {
          keyLength = 2048;
        };
      };
    };
    accounts' = {
      steffen = {
        aliases = [
          "postmaster"
          "info"
          "dmarc"
        ];
      };
      ulm = {
        aliases = [
          "postmaster"
          "info"
        ];
      };
      lissy = { };
      nextcloud = {
        sendOnly = true;
      };
      vaultwarden = {
        sendOnly = true;
      };
      git = {
        sendOnly = true;
      };
    };
  };

  security.acme.certs.${config.mailserver.fqdn} = {
    webroot = null;
    dnsProvider = "ionos";
    dnsResolver = "1.1.1.1:53";
    credentialFiles.IONOS_API_KEY_FILE = config.sops.secrets.ionos-api-key.path;
    reloadServices = [ "postfix.service" ];
  };

  sops.secrets.ionos-api-key = {
    mode = "0400";
    owner = "acme";
    group = "acme";
  };

  networking.hosts."127.0.0.1" = [ config.mailserver.fqdn ];

  systemd.services = lib.genAttrs [ "dovecot" "postfix" "rspamd" ] (_: {
    unitConfig.RequiresMountsFor = [ dataDir ];
  });

  services.postfix.settings = {
    main = {
      relayhost = [ "[${edgeIp}]:${toString c.mail-relay.port}" ];
      smtpd_client_auth_rate_limit = 10;
      smtpd_client_connection_rate_limit = 30;
    };
    master = {
      ${toString mp.smtp} = mkProxyListener [ ];
      ${toString mp.submission-tls} = mkProxyListener master.submissions.args;
    };
  };

  services.dovecot2.settings = {
    haproxy_trusted_networks = [ "${edgeIp}/32" ];
    "service imap-login"."inet_listener imaps_proxy" = {
      port = mp.imap;
      ssl = true;
      haproxy = true;
    };
  };
}
