{
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  m = c.mail;
  set = "f2b-mail";
  ports = lib.concatMapStringsSep "," toString [
    m.smtp
    m.submission-tls
    m.imap
  ];
  pubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8+pWt+R2P8u88UHx1lW7ItYniiN/30G7KxnlkEwwPi fail2ban@portuus";

  user = "f2b";
  ipset = "${config.security.wrapperDir}/f2b-ipset";

  apply = pkgs.writeShellApplication {
    name = "f2b-mail-apply";
    text = ''
      read -r verb ip secs <<< "''${SSH_ORIGINAL_COMMAND:-}"
      [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid ip" >&2; exit 1; }
      case "$verb" in
        ban)
          [[ "$secs" =~ ^[0-9]{1,9}$ ]] || { echo "invalid duration" >&2; exit 1; }
          (( secs > 2147483 )) && secs=2147483
          ${ipset} add -exist ${set} "$ip" timeout "$secs"
          ;;
        unban)
          ${ipset} del -exist ${set} "$ip"
          ;;
        *)
          echo "invalid command" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  users.users.${user} = {
    isSystemUser = true;
    group = user;
    shell = pkgs.bash;
    home = "/var/empty";
    openssh.authorizedKeys.keys = [
      ''restrict,from="${c.hosts.portuus.ip}",command="${lib.getExe apply}" ${pubKey}''
    ];
  };
  users.groups.${user} = { };

  security.wrappers.f2b-ipset = {
    source = "${pkgs.ipset}/bin/ipset";
    capabilities = "cap_net_admin+ep";
    owner = "root";
    group = user;
    permissions = "u+rx,g+x";
  };

  networking.firewall = {
    extraPackages = [ pkgs.ipset ];
    extraCommands = ''
      ipset create -exist ${set} hash:ip timeout 0
      iptables -I nixos-fw -p tcp -m multiport --dports ${ports} -m set --match-set ${set} src -j DROP
    '';
  };
}
