{
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  edgeIp = c.hosts.edge.ip;
  sshPort = 2299;
  edgeHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4G+/c0IY47B4sR5eo1Hv48MYQktZqVQnVFINrofEcq";
  knownHosts = pkgs.writeText "edge-known-hosts" "[${edgeIp}]:${toString sshPort} ${edgeHostKey}\n";

  ssh = lib.concatStringsSep " " [
    (lib.getExe pkgs.openssh)
    "-i ${config.sops.secrets."fail2ban/edge-ssh-key".path}"
    "-p ${toString sshPort}"
    "-o BatchMode=yes"
    "-o ConnectTimeout=10"
    "-o StrictHostKeyChecking=yes"
    "-o UserKnownHostsFile=${knownHosts}"
    "f2b@${edgeIp}"
  ];

  mailJail = filter: {
    enabled = true;
    inherit filter;
    backend = "systemd";
    action = "edge-mail";
    maxretry = 5;
    findtime = "10m";
  };
in
{
  services.fail2ban = {
    enable = true;
    ignoreIP = [
      "100.64.0.0/10"
      "fd7a:115c:a1e0::/48"
    ];
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      overalljails = true;
    };
    jails = {
      postfix-sasl.settings = mailJail "postfix[mode=auth]";
      dovecot-login.settings = mailJail "dovecot-login";
    };
  };

  environment.etc = {
    "fail2ban/filter.d/dovecot-login.conf".text = ''
      [INCLUDES]
      before = common.conf

      [Definition]
      _daemon = dovecot
      failregex = ^%(__prefix_line)s\S+-login: Login aborted: [^(]*\(auth failed, \d+ attempts(?: in \d+ secs)?\) \(auth_failed\): (?:user=<[^>]*>, )?(?:method=\S+, )?rip=<HOST>,
      journalmatch = _SYSTEMD_UNIT=dovecot.service
    '';
    "fail2ban/action.d/edge-mail.conf".text = ''
      [Definition]
      actionban = ${ssh} ban <ip> <bantime>
      actionunban = ${ssh} unban <ip>
    '';
  };

  sops.secrets."fail2ban/edge-ssh-key".mode = "0400";
}
