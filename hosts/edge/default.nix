{
  inputs,
  outputs,
  ...
}:

{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    ./packages.nix
    ./secrets
    ./services
    ./users.nix

    inputs.synix.nixosModules.common

    outputs.nixosModules.attic-client
    outputs.nixosModules.common
  ];

  services.attic-client.enable = true;

  system.stateVersion = "25.11";
}
