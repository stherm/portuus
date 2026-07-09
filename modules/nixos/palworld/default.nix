# Palworld dedicated server (SteamCMD app 2394010).
# steamcmd updates the server on every service start, steam-run provides the
# FHS environment for the dynamically linked PalServer binary.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.palworld;

  inherit (lib)
    concatStringsSep
    isBool
    isString
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optionalString
    types
    ;

  appId = "2394010";
  serverDir = "${cfg.dataDir}/server";
  iniPath = "${serverDir}/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini";

  renderValue =
    v:
    if isBool v then
      (if v then "True" else "False")
    else if isString v then
      ''"${v}"''
    else
      toString v;

  settings = {
    PublicPort = cfg.port;
  }
  // cfg.settings
  // optionalAttrs (cfg.serverPasswordFile != null) { ServerPassword = "@SERVER_PASSWORD@"; }
  // optionalAttrs (cfg.adminPasswordFile != null) { AdminPassword = "@ADMIN_PASSWORD@"; };

  settingsFile = pkgs.writeText "PalWorldSettings.ini" ''
    [/Script/Pal.PalGameWorldSettings]
    OptionSettings=(${
      concatStringsSep "," (
        mapAttrsToList (k: v: "${k}=${renderValue v}") settings ++ mapAttrsToList (k: v: "${k}=${v}") cfg.rawSettings
      )
    })
  '';
in
{
  options.services.palworld = {
    enable = mkEnableOption "Palworld dedicated server";

    port = mkOption {
      type = types.port;
      default = 8211;
      description = "UDP port the game server listens on.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/palworld";
      description = "Directory holding the server installation and save games.";
    };

    settings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.bool
          types.int
          types.float
          types.str
        ]
      );
      default = { };
      example = {
        ServerName = "My Server";
        ServerPlayerMaxNum = 16;
      };
      description = ''
        OptionSettings entries for PalWorldSettings.ini.
        Unset options fall back to the server defaults.
      '';
    };

    rawSettings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        Difficulty = "None";
        CrossplayPlatforms = "(Steam,Xbox,PS5,Mac)";
      };
      description = ''
        OptionSettings entries written verbatim without quoting, for enum
        values and tuples that settings cannot express.
      '';
    };

    serverPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the join password (sops secret).";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the admin password (sops secret).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [
        "-useperfthreads"
        "-NoAsyncLoadingThread"
        "-UseMultithreadForDS"
      ];
      description = "Extra command line flags for PalServer.sh.";
    };

    restartDaily = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Restart the server every morning. Works around the well-known
        Palworld memory leak and picks up server updates via steamcmd.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.palworld = {
      isSystemUser = true;
      group = "palworld";
      home = cfg.dataDir;
    };
    users.groups.palworld = { };

    systemd = {
      services = {
        palworld = {
          description = "Palworld dedicated server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];

          # steamcmd bootstraps itself into $HOME/.local/share/Steam
          environment.HOME = cfg.dataDir;

          path = [
            pkgs.steamcmd
            pkgs.steam-run
          ];

          preStart = ''
            steamcmd \
              +force_install_dir ${serverDir} \
              +login anonymous \
              +app_update ${appId} validate \
              +quit

            # PalServer expects steamclient.so under ~/.steam/sdk64
            mkdir -p "$HOME/.steam/sdk64"
            ln -sf "$HOME/.local/share/Steam/linux64/steamclient.so" "$HOME/.steam/sdk64/steamclient.so"

            install -D -m 600 ${settingsFile} ${iniPath}
            ${optionalString (cfg.serverPasswordFile != null) ''
              ${pkgs.replace-secret}/bin/replace-secret '@SERVER_PASSWORD@' ${cfg.serverPasswordFile} ${iniPath}
            ''}
            ${optionalString (cfg.adminPasswordFile != null) ''
              ${pkgs.replace-secret}/bin/replace-secret '@ADMIN_PASSWORD@' ${cfg.adminPasswordFile} ${iniPath}
            ''}
          '';

          script = ''
            exec steam-run ${serverDir}/PalServer.sh \
              -port=${toString cfg.port} \
              ${concatStringsSep " " cfg.extraFlags}
          '';

          serviceConfig = {
            User = "palworld";
            Group = "palworld";
            StateDirectory = mkIf (cfg.dataDir == "/var/lib/palworld") "palworld";
            WorkingDirectory = cfg.dataDir;
            Restart = "on-failure";
            # first start downloads the ~12 GB server via steamcmd
            TimeoutStartSec = "2h";
          };
        };

        palworld-restart = mkIf cfg.restartDaily {
          serviceConfig.Type = "oneshot";
          script = "systemctl restart palworld.service";
        };
      };

      timers.palworld-restart = mkIf cfg.restartDaily {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "05:30";
          Persistent = true;
        };
      };
    };
  };
}
