{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.gmod;

  inherit (lib)
    concatStringsSep
    escapeShellArg
    isBool
    isInt
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  serverDir = "${cfg.dataDir}/server";
  cssDir = "${cfg.dataDir}/css";
  gmodDir = "${serverDir}/garrysmod";

  renderValue =
    v:
    if isBool v then
      (if v then "1" else "0")
    else if isInt v then
      toString v
    else
      ''"${v}"'';

  serverCfg = pkgs.writeText "server.cfg" ''
    hostname ${renderValue cfg.hostname}
    sv_password "@SERVER_PASSWORD@"
    rcon_password "@RCON_PASSWORD@"
    sv_lan 0
    ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k} ${renderValue v}") cfg.settings)}
  '';

  mountCfg = pkgs.writeText "mount.cfg" ''
    "mountcfg"
    {
      "cstrike" "${cssDir}/cstrike"
    }
  '';
in
{
  options.services.gmod = {
    enable = mkEnableOption "Garry's Mod dedicated server";

    port = mkOption {
      type = types.port;
      default = 27015;
      description = "UDP port of the game server.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/gmod";
      description = "Directory holding the server installation, mounted content and workshop cache.";
    };

    hostname = mkOption {
      type = types.str;
      default = "Garry's Mod";
      description = "Server name shown to players.";
    };

    gamemode = mkOption {
      type = types.str;
      default = "terrortown";
      description = "Gamemode to start.";
    };

    map = mkOption {
      type = types.str;
      default = "gm_construct";
      description = "Map to start with.";
    };

    maxPlayers = mkOption {
      type = types.ints.positive;
      default = 16;
      description = "Maximum number of players.";
    };

    workshopCollection = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "2042277791";
      description = ''
        Steam workshop collection the server mounts. All items are also
        announced to clients via resource.AddWorkshop so they download them.
      '';
    };

    serverPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the join password.";
    };

    rconPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the RCON password.";
    };

    settings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.bool
          types.int
          types.str
        ]
      );
      default = { };
      example = {
        ttt_karma = true;
        ttt_traitor_pct = "0.34";
      };
      description = "Console variables written to server.cfg. Strings are quoted, so floats can be given as strings.";
    };

    mountCss = mkOption {
      type = types.bool;
      default = false;
      description = "Download the Counter-Strike: Source dedicated server content and mount it, as many TTT maps use its assets.";
    };

    restartDaily = mkOption {
      type = types.bool;
      default = true;
      description = "Restart the server every morning to pick up game and workshop updates.";
    };
  };

  config = mkIf cfg.enable {
    users.users.gmod = {
      isSystemUser = true;
      group = "gmod";
      home = cfg.dataDir;
    };
    users.groups.gmod = { };

    systemd = {
      tmpfiles.rules = [ "d ${cfg.dataDir} 0750 gmod gmod - -" ];

      services = {
        gmod-dirs = {
          description = "Garry's Mod data directory";
          requiredBy = [ "gmod.service" ];
          before = [ "gmod.service" ];
          unitConfig.RequiresMountsFor = [ cfg.dataDir ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${cfg.dataDir}";
          };
        };

        gmod = {
          description = "Garry's Mod dedicated server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.RequiresMountsFor = [ cfg.dataDir ];

          environment.HOME = cfg.dataDir;

          path = with pkgs; [
            coreutils
            curl
            jq
            steamcmd
            steam-run
          ];

          preStart = ''
            steamcmd \
              +force_install_dir ${serverDir} \
              +login anonymous \
              +app_update 4020 -beta x86-64 validate \
              +quit
            ${optionalString cfg.mountCss ''
              steamcmd \
                +force_install_dir ${cssDir} \
                +login anonymous \
                +app_update 232330 validate \
                +quit
              install -D -m 644 ${mountCfg} ${gmodDir}/cfg/mount.cfg
            ''}

            mkdir -p "$HOME/.steam/sdk32" "$HOME/.steam/sdk64"
            ln -sf "$HOME/.local/share/Steam/linux32/steamclient.so" "$HOME/.steam/sdk32/steamclient.so"
            ln -sf "$HOME/.local/share/Steam/linux64/steamclient.so" "$HOME/.steam/sdk64/steamclient.so"

            install -D -m 600 ${serverCfg} ${gmodDir}/cfg/server.cfg
            ${optionalString (cfg.serverPasswordFile != null) ''
              ${pkgs.replace-secret}/bin/replace-secret '@SERVER_PASSWORD@' ${cfg.serverPasswordFile} ${gmodDir}/cfg/server.cfg
            ''}
            ${optionalString (cfg.rconPasswordFile != null) ''
              ${pkgs.replace-secret}/bin/replace-secret '@RCON_PASSWORD@' ${cfg.rconPasswordFile} ${gmodDir}/cfg/server.cfg
            ''}

            ${optionalString (cfg.workshopCollection != null) ''
              lua=${gmodDir}/lua/autorun/server/portuus_workshop.lua
              mkdir -p "$(dirname "$lua")"
              if curl -fsS --max-time 60 \
                  -d collectioncount=1 \
                  -d 'publishedfileids[0]=${cfg.workshopCollection}' \
                  https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/ \
                | jq -r '.response.collectiondetails[0].children[].publishedfileid | "resource.AddWorkshop(\"\(.)\")"' \
                > "$lua.tmp" && [ -s "$lua.tmp" ]; then
                mv "$lua.tmp" "$lua"
              else
                rm -f "$lua.tmp"
                echo "could not refresh workshop list, keeping the previous one"
              fi
            ''}
          '';

          script = ''
            cd ${serverDir}
            run=./srcds_run_x64
            [ -x "$run" ] || run=./srcds_run
            exec steam-run "$run" \
              -game garrysmod \
              -console \
              -norestart \
              -port ${toString cfg.port} \
              +maxplayers ${toString cfg.maxPlayers} \
              +gamemode ${escapeShellArg cfg.gamemode} \
              +map ${escapeShellArg cfg.map} \
              ${optionalString (cfg.workshopCollection != null) "+host_workshop_collection ${cfg.workshopCollection}"}
          '';

          serviceConfig = {
            User = "gmod";
            Group = "gmod";
            WorkingDirectory = cfg.dataDir;
            Restart = "on-failure";
            RestartSec = "30s";
            TimeoutStartSec = "2h";
          };
        };

        gmod-restart = mkIf cfg.restartDaily {
          serviceConfig.Type = "oneshot";
          script = "systemctl restart gmod.service";
        };
      };

      timers.gmod-restart = mkIf cfg.restartDaily {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "05:30";
          Persistent = true;
        };
      };
    };
  };
}
