{ constants, lib, ... }:

let
  c = constants;
  ip = c.hosts.portuus.ip;
  rd = c.services.rustdesk.ports;
  mc = c.services;
  m = c.mail;

  minecraft = builtins.filter (s: s.enable) [
    mc.minecraft-survival
    mc.minecraft-creative
    mc.minecraft-amplified
  ];
  inherit (mc) palworld;
in
{
  services.nginx = {
    streamConfig = ''
      server { listen ${toString m.smtp};           proxy_pass ${ip}:${toString m.smtp}; }
      server { listen ${toString m.submission};      proxy_pass ${ip}:${toString m.submission}; }
      server { listen ${toString m.submission-tls};  proxy_pass ${ip}:${toString m.submission-tls}; }
      server { listen ${toString m.imap};            proxy_pass ${ip}:${toString m.imap}; }

      server { listen ${toString mc.gitlab.sshPort}; proxy_pass ${ip}:2299; }

      ${lib.concatMapStringsSep "\n" (
        s: "server { listen ${toString s.port}; proxy_pass ${ip}:${toString s.port}; }"
      ) minecraft}

      ${lib.optionalString palworld.enable "server { listen ${toString palworld.port} udp; proxy_pass ${ip}:${toString palworld.port}; }"}

      server { listen ${toString rd.nat-test};  proxy_pass ${ip}:${toString rd.nat-test}; }
      server { listen ${toString rd.id};        proxy_pass ${ip}:${toString rd.id}; }
      server { listen ${toString rd.id} udp;    proxy_pass ${ip}:${toString rd.id}; }
      server { listen ${toString rd.relay};     proxy_pass ${ip}:${toString rd.relay}; }
      server { listen ${toString rd.ws};        proxy_pass ${ip}:${toString rd.ws}; }
      server { listen ${toString rd.ws-relay};  proxy_pass ${ip}:${toString rd.ws-relay}; }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [
      m.smtp
      m.submission-tls
      m.submission
      m.imap
      mc.gitlab.sshPort
      rd.nat-test
      rd.id
      rd.relay
      rd.ws
      rd.ws-relay
    ]
    ++ map (s: s.port) minecraft;

    allowedUDPPorts = [
      rd.id
    ]
    ++ lib.optional palworld.enable palworld.port;
  };
}
