{ config, pkgs, ... }:

{
  environment.systemPackages = [
    (
      let
        newPostgres = pkgs.postgresql_17.withPackages (ps: [
          ps.pgvector
          ps.vectorchord
        ]);
      in
      pkgs.writeScriptBin "upgrade-pg-cluster" ''
        set -eux
        systemctl stop postgresql
        export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
        export NEWBIN="${newPostgres}/bin"
        export OLDDATA="${config.services.postgresql.dataDir}"
        export OLDBIN="${config.services.postgresql.finalPackage}/bin"
        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA"
        sudo -u postgres "$NEWBIN/pg_upgrade" \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
          "$@"
      ''
    )
  ];
}
