{ constants, lib, ... }:

let
  c = constants;
in
{
  services.postfix = {
    enable = true;
    transport = "${c.domain} smtp:[${c.hosts.portuus.ip}]:${toString c.mail.smtp}";
    settings = {
      master.smtp_inet.name = lib.mkForce (toString c.mail-relay.port);
      main = {
        myhostname = "mail.${c.domain}";
        myorigin = c.domain;
        mydestination = [ ];
        relay_domains = [ ];
        mynetworks = [
          "127.0.0.0/8"
          "${c.hosts.portuus.ip}/32"
        ];
        smtpd_relay_restrictions = [
          "permit_mynetworks"
          "reject"
        ];
        smtpd_recipient_restrictions = [
          "permit_mynetworks"
          "reject"
        ];
        smtp_tls_security_level = "may";
        inet_protocols = "ipv4";
        message_size_limit = 20971520;
      };
    };
  };
}
