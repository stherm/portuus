{
  outputs,
  config,
  constants,
  pkgs,
  ...
}:

let
  s = constants.services.attic;
  user = "attic-watch-store";
  endpoint = "http://127.0.0.1:${toString s.port}";
  configDir = "${user}/attic";
in
{
  imports = [ outputs.nixosModules.attic-client ];

  services.attic-client = {
    enable = true;
    inherit endpoint;
    tokenSecret = "attic/push-token";
  };

  users = {
    users.${user} = {
      isSystemUser = true;
      group = user;
    };
    groups.${user} = { };
  };

  systemd.services.attic-watch-store = {
    description = "Push new store paths to the attic cache";
    wantedBy = [ "multi-user.target" ];
    after = [ "atticd.service" ];
    requires = [ "atticd.service" ];
    environment.XDG_CONFIG_HOME = builtins.dirOf (builtins.dirOf config.sops.templates."${configDir}/config.toml".path);
    serviceConfig = {
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store local:${s.cache}";
      User = user;
      Group = user;
      Restart = "always";
      RestartSec = 10;
    };
  };

  sops.templates."${configDir}/config.toml" = {
    owner = user;
    content = ''
      default-server = "local"

      [servers.local]
      endpoint = "${endpoint}"
      token = "${config.sops.placeholder."attic/push-token"}"
    '';
    restartUnits = [ "attic-watch-store.service" ];
  };
}
