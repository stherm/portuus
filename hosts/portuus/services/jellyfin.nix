{
  inputs,
  config,
  constants,
  lib,
  pkgs,
  ...
}:

let
  c = constants;
  s = c.services.jellyfin;
  cfg = config.services.jellyfin;
  dataDir = "/data/jellyfin";

  configScript = pkgs.writeShellApplication {
    name = "jellyfin-config";
    runtimeInputs = [ pkgs.xmlstarlet ];
    text = ''
      setValue() {
        local file=$1 path=$2 value=$3
        [ -f "$file" ] || return 0
        if xmlstarlet sel -t -c "$path" "$file" >/dev/null 2>&1; then
          xmlstarlet ed -L -u "$path" -v "$value" "$file"
        else
          xmlstarlet ed -L -s "''${path%/*}" -t elem -n "''${path##*/}" -v "$value" "$file"
        fi
      }

      setList() {
        local file=$1 path=$2
        shift 2
        [ -f "$file" ] || return 0
        xmlstarlet ed -L -d "$path" "$file"
        xmlstarlet ed -L -s "''${path%/*}" -t elem -n "''${path##*/}" "$file"
        for item in "$@"; do
          xmlstarlet ed -L -s "$path" -t elem -n string -v "$item" "$file"
        done
      }

      network=${cfg.configDir}/network.xml
      system=${cfg.configDir}/system.xml

      setValue "$network" /NetworkConfiguration/AutoDiscovery false
      setValue "$network" /NetworkConfiguration/EnableRemoteAccess true
      setList "$network" /NetworkConfiguration/KnownProxies 127.0.0.1
      setList "$network" /NetworkConfiguration/LocalNetworkSubnets 192.168.178.0/24 100.64.0.0/10

      setValue "$system" /ServerConfiguration/RemoteClientBitrateLimit 15000000
      setValue "$system" /ServerConfiguration/QuickConnectAvailable true
      setValue "$system" /ServerConfiguration/EnableMetrics false
      setValue "$system" /ServerConfiguration/TrickplayOptions/EnableHwAcceleration true
      setValue "$system" /ServerConfiguration/TrickplayOptions/EnableHwEncoding true
    '';
  };
in
{
  imports = [ inputs.synix.nixosModules.jellyfin ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  services = {
    jellyfin = {
      enable = true;
      inherit dataDir;
      reverseProxy = {
        enable = true;
        inherit (s) subdomain;
        forceSSL = false;
      };
      libraries = [
        "movies"
        "shows"
      ];

      hardwareAcceleration = {
        enable = true;
        type = "qsv";
        device = "/dev/dri/renderD128";
      };
      forceEncodingConfig = true;
      transcoding = {
        enableHardwareEncoding = true;
        enableIntelLowPowerEncoding = true;
        enableToneMapping = true;
        throttleTranscoding = true;
        deleteSegments = true;
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          vc1 = true;
          vp9 = true;
          av1 = true;
        };
        hardwareEncodingCodecs = {
          hevc = true;
          av1 = true;
        };
      };
    };

    nginx.virtualHosts.${s.fqdn}.extraConfig = ''
      set_real_ip_from ${c.hosts.edge.ip};
      real_ip_header X-Real-IP;
    '';
  };

  users = {
    users.${cfg.user} = {
      uid = 994;
      extraGroups = [
        "render"
        "video"
      ];
    };
    groups.${cfg.group}.gid = 991;
  };

  systemd.services = {
    jellyfin-config = {
      description = "Apply portuus settings to the Jellyfin configuration";
      requiredBy = [ "jellyfin.service" ];
      before = [ "jellyfin.service" ];
      unitConfig.RequiresMountsFor = [ dataDir ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.getExe configScript;
      };
    };

    jellyfin.unitConfig.RequiresMountsFor = [ dataDir ];
  };
}
