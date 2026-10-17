{ config, ... }:

let
  envFile = config.sops.templates."rustdesk-server/env".path;
in
{
  sops = {
    secrets."rustdesk-server/key" = { };
    templates."rustdesk-server/env" = {
      content = ''
        KEY=${config.sops.placeholder."rustdesk-server/key"}
      '';
      restartUnits = [
        "rustdesk-signal.service"
        "rustdesk-relay.service"
      ];
    };
  };

  services.rustdesk-server = {
    enable = true;
    openFirewall = false;
    signal = {
      enable = true;
      relayHosts = [ config.networking.domain ];
    };
    relay = {
      enable = true;
    };
  };

  systemd.services = {
    rustdesk-signal.serviceConfig.EnvironmentFile = envFile;
    rustdesk-relay.serviceConfig.EnvironmentFile = envFile;
  };
}
