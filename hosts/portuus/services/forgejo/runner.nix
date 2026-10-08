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
    settings.runner.capacity = 2;
  };

  systemd.services.gitea-runner-nix.serviceConfig.SupplementaryGroups = lib.mkForce [ ];

  nix.settings.allowed-users = [ "*" ];

  sops = {
    secrets."gitea-actions-runner/nix/token" = { };
    templates."gitea-actions-runner/nix/token".content = ''
      TOKEN=${config.sops.placeholder."gitea-actions-runner/nix/token"}
    '';
  };
}
