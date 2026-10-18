{ pkgs, lib, ... }:

{
  imports = [
    ./overlays.nix
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./deploy_key.pub
  ];

  nix.settings.trusted-users = [ "root" ];
  nix.settings.accept-flake-config = lib.mkForce false;

  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "prohibit-password";
    KbdInteractiveAuthentication = false;
    Compression = false;
  };
}
