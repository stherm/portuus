{ constants, pkgs, ... }:

let
  c = constants;
  mailFqdn = "mail.${c.domain}";

  mkServer = tag: type: port: ''
    <${tag} type="${type}">
      <hostname>${mailFqdn}</hostname>
      <port>${toString port}</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </${tag}>
  '';

  autoconfig = pkgs.writeTextDir "mail/config-v1.1.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <clientConfig version="1.1">
      <emailProvider id="${c.domain}">
        <domain>${c.domain}</domain>
        <displayName>${c.domain} Mail</displayName>
        <displayShortName>${c.domain}</displayShortName>
        ${mkServer "incomingServer" "imap" c.mail.imap}
        ${mkServer "outgoingServer" "smtp" c.mail.submission-tls}
      </emailProvider>
    </clientConfig>
  '';
in
{
  services.nginx.virtualHosts."autoconfig.${c.domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."/mail/".root = autoconfig;
  };
}
