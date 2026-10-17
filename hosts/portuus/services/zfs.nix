{
  config,
  pkgs,
  lib,
  ...
}:

let
  snapshotDatasets = [
    "dpool/data/backup"
    "dpool/data/charbogen"
    "dpool/data/forgejo"
    "dpool/data/immich"
    "dpool/data/mail"
    "dpool/data/matrix-synapse"
    "dpool/data/maubot"
    "dpool/data/nextcloud"
  ];
in
{
  services.zfs = {
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
      frequent = 0;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };

    autoReplication = {
      host = "";
      username = "root";
      identityFilePath = "/root/.ssh/zfs-replication";
      localFilesystem = "dpool/data/backup";
      remoteFilesystem = "dpool/portuus-backup";
      followDelete = true;
    };

    zed = {
      enableMail = true;
      settings = {
        ZED_EMAIL_ADDR = "postmaster@portuus.de";
        ZED_EMAIL_PROG = "sendmail";
        ZED_EMAIL_OPTS = "-t -f root@localhost";
        ZED_NOTIFY_VERBOSE = "1";
        ZED_NOTIFY_DATA = "1";
        ZED_NOTIFY_ERROR = "1";
        ZED_NOTIFY_WARNING = "1";
      };
    };
  };

  systemd.services.zfs-autosnapshot-props = {
    description = "Mark ZFS datasets for automatic snapshots";
    after = [ "zfs-import.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.boot.zfs.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStrings (ds: ''
      zfs set com.sun:auto-snapshot=true ${ds}
    '') snapshotDatasets;
  };

  environment.systemPackages = with pkgs; [ lz4 ];
}
