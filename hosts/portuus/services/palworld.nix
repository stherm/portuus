{
  outputs,
  config,
  constants,
  ...
}:

let
  s = constants.services.palworld;
in
{
  imports = [ outputs.nixosModules.palworld ];

  sops.secrets = {
    "palworld/server-password" = {
      owner = "palworld";
      restartUnits = [ "palworld.service" ];
    };
    "palworld/admin-password" = {
      owner = "palworld";
      restartUnits = [ "palworld.service" ];
    };
  };

  services.palworld = {
    enable = true;
    inherit (s) port;
    serverPasswordFile = config.sops.secrets."palworld/server-password".path;
    adminPasswordFile = config.sops.secrets."palworld/admin-password".path;
    settings = {
      ServerName = "Portuus Palworld";
      ServerDescription = "Privater Palworld-Server";
      ServerPlayerMaxNum = 16;
    };
  };

  # no openFirewall needed: traffic comes via edge stream proxy over the
  # Tailnet, and synix trusts the tailscale interface
}
