{
  pkgs,
  lib,
  constants,
  ...
}:

{
  imports = [
    ./overlays.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    ''from="127.0.0.1,::1,${constants.hosts.portuus.ip}" ${lib.fileContents ./deploy_key.pub}''
  ];

  nix.settings.trusted-users = [ "root" ];

  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "prohibit-password";
    KbdInteractiveAuthentication = false;
    Compression = false;
  };
}
