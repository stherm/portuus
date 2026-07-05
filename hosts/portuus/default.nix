{
  inputs,
  outputs,
  lib,
  ...
}:

{
  # Central unfree allowlist: multiple allowUnfreePredicate definitions
  # silently override each other, so all services share this one.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "minecraft-server"
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
      "steamcmd"
    ];

  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    ./packages.nix
    ./programs.nix
    ./secrets
    ./services
    ./users.nix

    inputs.synix.nixosModules.common

    outputs.nixosModules.common
  ];

  system.stateVersion = "24.11";
}
