rec {
  domain = "portuus.de";

  hosts = {
    portuus = {
      ip = "100.64.0.2";
      edgeBackupKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgY0vxCSmHl4ueA5mEKaO8RrCOVjLwmDdtF4OOHqSYp portuus-edge-backup";
    };
    edge = {
      ip = "100.64.0.1";
    };
    jetkvm = {
      ip = "100.64.0.3";
    };
  };

  services = {
    attic = {
      subdomain = "cache";
      fqdn = "cache." + domain;
      port = 8180;
      cache = "portuus";
      publicKey = "portuus:OEIdyRk2znvu8n4B+2FnNmWjOWnKxRACfQfuIYHNd8s=";
    };
    charbogen = {
      fqdn = "roll-dice.org";
      authFqdn = "auth.roll-dice.org";
      port = 5000;
    };
    feuerwehr = {
      fqdn = "feuerwehr-friesenhagen.de";
    };
    forgejo = {
      subdomain = "git";
      testSubdomain = "test";
      fqdn = "git." + domain;
      testFqdn = "test." + domain;
      port = 3456;
      sshPort = 2222;
    };
    headscale = {
      subdomain = "hs";
      fqdn = "hs." + domain;
    };
    immich = {
      subdomain = "gallery";
      fqdn = "gallery." + domain;
      port = 2283;
    };
    jirafeau = {
      subdomain = "share";
      fqdn = "share." + domain;
    };
    matrix-synapse = {
      fqdn = domain;
      port = 8008;
    };
    maubot = {
      port = 29316;
    };
    minecraft-survival = {
      enable = false;
      port = 25565;
    };
    minecraft-creative = {
      enable = false;
      port = 25566;
    };
    minecraft-amplified = {
      enable = false;
      port = 25567;
    };
    minecraft-cobbleverse = {
      enable = true;
      port = 25568;
    };
    nextcloud = {
      subdomain = "cloud";
      fqdn = "cloud." + domain;
    };
    palworld = {
      enable = false;
      port = 8211;
    };
    radicale = {
      subdomain = "dav";
      fqdn = "dav." + domain;
    };
    rustdesk = {
      ports = {
        nat-test = 21115;
        id = 21116;
        relay = 21117;
        ws = 21118;
        ws-relay = 21119;
      };
    };
    vaultwarden = {
      subdomain = "vault";
      fqdn = "vault." + domain;
      port = 8222;
    };
  };

  mail = {
    domains = [
      domain
      services.charbogen.fqdn
      services.feuerwehr.fqdn
    ];
    smtp = 25;
    submission-tls = 465;
    imap = 993;
  };

  mail-proxy = {
    smtp = 10025;
    submission-tls = 10465;
    imap = 10993;
  };

  branding = import ./assets/branding;

  mail-relay = {
    port = 2525;
  };
}
