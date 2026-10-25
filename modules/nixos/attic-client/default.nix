{
  config,
  constants,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.attic-client;
  s = constants.services.attic;
  machine = builtins.head (builtins.match "https?://([^:/]+).*" cfg.endpoint);
in
{
  options.services.attic-client = {
    enable = mkEnableOption "the portuus attic binary cache as substituter";

    endpoint = mkOption {
      type = types.str;
      default = "https://${s.fqdn}";
      description = "Base URL of the attic server.";
    };

    cache = mkOption {
      type = types.str;
      default = s.cache;
      description = "Name of the attic cache.";
    };

    tokenSecret = mkOption {
      type = types.str;
      default = "attic/pull-token";
      description = "sops secret holding the attic token used for pulling.";
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      substituters = [ "${cfg.endpoint}/${cfg.cache}" ];
      trusted-public-keys = [ s.publicKey ];
      netrc-file = config.sops.templates."attic-client/netrc".path;
      connect-timeout = 5;
    };

    sops = {
      secrets.${cfg.tokenSecret} = { };
      templates."attic-client/netrc".content = ''
        machine ${machine} password ${config.sops.placeholder.${cfg.tokenSecret}}
      '';
    };
  };
}
