{
  outputs,
  ...
}:

{
  imports = [
    ./attic.nix
    ./attic-watch-store.nix
    ./charbogen.nix
    ./edge-backup.nix
    ./fail2ban.nix
    ./forgejo
    ./github-runners.nix
    ./immich.nix
    ./jirafeau.nix
    ./mailserver.nix
    ./matrix-synapse.nix
    ./minecraft-servers.nix
    ./nextcloud.nix
    ./nginx.nix
    ./openssh.nix
    ./palworld.nix
    ./postgresql.nix
    ./radicale.nix
    ./rustdesk-server.nix
    ./vaultwarden.nix
    ./website-ff.nix
    ./zfs.nix

    outputs.nixosModules.tailscale
  ];
}
