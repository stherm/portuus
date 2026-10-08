{
  outputs,
  ...
}:

{
  imports = [
    ./headscale.nix
    ./jetkvm-proxy.nix
    ./livekit.nix
    ./mail-autoconfig.nix
    ./mail-ban.nix
    ./mail-relay.nix
    ./nginx.nix
    ./openssh.nix
    ./portuus-proxy.nix
    ./roll-dice-proxy.nix
    ./stream-proxy.nix

    outputs.nixosModules.tailscale
  ];
}
