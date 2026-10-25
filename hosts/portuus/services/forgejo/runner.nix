{
  inputs,
  config,
  lib,
  ...
}:

{
  imports = [ inputs.synix.nixosModules.gitea-actions-runner ];

  services.gitea-actions-runner.instances.nix = {
    enable = true;
    url = "http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}";
    tokenFile = config.sops.templates."gitea-actions-runner/nix/token".path;
    settings = {
      runner.capacity = 2;
      host.workdir_parent = "/var/lib/gitea-runner-work";
    };
  };

  systemd = {
    services.gitea-runner-nix.serviceConfig = {
      SupplementaryGroups = lib.mkForce [ ];
      ReadWritePaths = [ "/var/lib/gitea-runner-work" ];
    };
    tmpfiles.rules = [ "d /var/lib/gitea-runner-work 0750 gitea-runner gitea-runner - -" ];
  };

  nix.settings = {
    allowed-users = [ "*" ];
    trusted-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];
  };

  sops = {
    secrets."gitea-actions-runner/nix/token" = { };
    templates."gitea-actions-runner/nix/token".content = ''
      TOKEN=${config.sops.placeholder."gitea-actions-runner/nix/token"}
    '';
  };
}
