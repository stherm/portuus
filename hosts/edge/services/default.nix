{
  outputs,
  ...
}:

{
  imports = [
    # ./coturn.nix
    ./headscale.nix
    ./jetkvm-proxy.nix
    ./livekit.nix
    ./nginx.nix
    ./openssh.nix
    ./portuus-proxy.nix
    ./stream-proxy.nix

    outputs.nixosModules.tailscale
  ];
}
