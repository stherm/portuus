{
  inputs,
  config,
  pkgs,
  lib,
  constants,
  ...
}:

let
  hs = config.services.headscale.settings;

  backupScript = pkgs.writeShellScript "headscale-backup" ''
    set -euo pipefail
    tmp=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT
    ${pkgs.sqlite}/bin/sqlite3 ${hs.database.sqlite.path} ".backup '$tmp/db.sqlite'"
    ${pkgs.coreutils}/bin/cp ${hs.noise.private_key_path} ${hs.derp.server.private_key_path} "$tmp"/
    ${pkgs.gnutar}/bin/tar -C "$tmp" -cf - . | ${pkgs.zstd}/bin/zstd -q
  '';
in
{
  imports = [
    inputs.synix.nixosModules.headscale
  ];

  services.headscale = {
    enable = true;
    openFirewall = true;
    reverseProxy = {
      enable = true;
      subdomain = "hs";
    };
    settings.dns.extra_records = [
      {
        name = "matrix.tail";
        type = "A";
        value = constants.hosts.portuus.ip;
      }
    ];
  };

  environment.etc."headscale/acl.hujson".source = lib.mkForce ./acl.hujson;

  services.nginx.virtualHosts.${constants.services.headscale.fqdn}.locations = {
    "= /".return = "302 https://${constants.domain}/";
    "^~ /swagger".return = "404";
  };

  networking.hosts."127.0.0.1" = [ constants.services.headscale.fqdn ];

  systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = "5min";

  users.users.root.openssh.authorizedKeys.keys = [
    ''restrict,from="${constants.hosts.portuus.ip}",command="${backupScript}" ${constants.hosts.portuus.edgeBackupKey}''
  ];
}
