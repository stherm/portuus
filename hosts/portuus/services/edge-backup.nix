{
  pkgs,
  constants,
  ...
}:

let
  dir = "/data/backup/edge";
in
{
  systemd.services.edge-backup = {
    description = "Pull headscale state from edge";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.RequiresMountsFor = [ "/data/backup" ];
    path = [
      pkgs.coreutils
      pkgs.openssh
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      install -d -m 0700 ${dir}
      ssh -i /root/.ssh/edge-backup -p 2299 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/root/.ssh/known_hosts_edge \
        root@${constants.hosts.edge.ip} > ${dir}/headscale.tar.zst.tmp
      test -s ${dir}/headscale.tar.zst.tmp
      mv ${dir}/headscale.tar.zst.tmp ${dir}/headscale.tar.zst
    '';
    startAt = "*-*-* 01:30:00";
  };
}
