{ pkgs, ... }:

{
  services.postgresql.package = pkgs.postgresql_17;

  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    location = "/data/backup/postgresql";
    compression = "zstd";
  };

  systemd.services.postgresqlBackup.unitConfig.RequiresMountsFor = [ "/data/backup" ];
}
