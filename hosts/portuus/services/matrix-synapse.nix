{
  inputs,
  config,
  lib,
  constants,
  ...
}:

{
  imports = [
    inputs.synix.nixosModules.matrix-synapse
    inputs.synix.nixosModules.maubot
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services = {
    matrix-synapse = {
      enable = true;
      sops = true;
      dataDir = "/data/matrix-synapse";
      bridges = {
        whatsapp = {
          enable = true;
          admin = "@steffen:portuus.de";
        };
        signal = {
          enable = true;
          admin = "@steffen:portuus.de";
        };
      };
    };

    maubot = {
      enable = true;
      sops = true;
      dataDir = "/data/maubot";
      admins = [
        "steffen"
      ];
      plugins = with config.services.maubot.package.plugins; [
        gitlab
        reminder
      ];
    };

    livekit.enable = lib.mkForce false;
    lk-jwt-service.enable = lib.mkForce false;

    # TLS terminated on edge
    nginx.virtualHosts."${config.networking.domain}" = {
      enableACME = lib.mkForce false;
      forceSSL = lib.mkForce false;
      listen = lib.mkForce [
        {
          addr = constants.hosts.portuus.ip;
          port = 80;
        }
      ];
    };
  };
}
