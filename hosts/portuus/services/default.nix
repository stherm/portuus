{
  outputs,
  ...
}:

{
  imports = [
    ./charbogen.nix
    ./forgejo
    ./github-runners.nix
    # ./gitlab-runner.nix
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
    ./zfs.nix

    outputs.nixosModules.tailscale
  ];
}
