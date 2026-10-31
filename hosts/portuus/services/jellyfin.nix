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
  b = c.branding;

  customCss = pkgs.writeText "jellyfin-portuus.css" (
    b.cssVariables + builtins.readFile ../../../assets/branding/jellyfin.css
  );

  banner = pkgs.runCommand "portuus-banner" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    mkdir $out
    logo=$(base64 -w0 ${b.logo})
    cat > $out/banner.svg <<EOF
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100">
      <image href="data:image/svg+xml;base64,$logo" x="0" y="0" width="100" height="100"/>
      <text x="112" y="68" font-family="system-ui, sans-serif" font-size="52" font-weight="700" fill="${b.colors.text}">portuus</text>
    </svg>
    EOF
    rsvg-convert -w 800 -h 200 $out/banner.svg -o $out/banner.png
  '';

  icons = b.iconDir { inherit lib pkgs; } {
    "favicon.ico" = 48;
    "touchicon.png" = 180;
    "touchicon144.png" = 144;
    "icon-transparent.png" = 512;
    "32px.png" = 32;
    "40px.png" = 40;
  };

  hashedAsset = name: ext: file: {
    "~ ^/web/${name}\\.[0-9a-f]+\\.${ext}$" = {
      root = file.dir;
      extraConfig = ''
        try_files /${file.name} =404;
        add_header Cache-Control "public, max-age=86400";
      '';
    };
  };

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

      branding=${cfg.configDir}/branding.xml
      if [ -d ${cfg.configDir} ] && [ ! -f "$branding" ]; then
        printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>' '<BrandingOptions />' > "$branding"
      fi
      setValue "$branding" /BrandingOptions/CustomCss "$(cat ${customCss})"
      setValue "$branding" /BrandingOptions/LoginDisclaimer "Accounts are handed out by the portuus admins."
      setValue "$branding" /BrandingOptions/SplashscreenEnabled false
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

    nginx.virtualHosts.${s.fqdn} = {
      extraConfig = ''
        set_real_ip_from ${c.hosts.edge.ip};
        real_ip_header X-Real-IP;
      '';
      locations = lib.mkMerge [
        { "= /web/portuus-banner.svg".alias = "${banner}/banner.svg"; }
        (hashedAsset "banner-light" "png" {
          dir = banner;
          name = "banner.png";
        })
        (hashedAsset "banner-dark" "png" {
          dir = banner;
          name = "banner.png";
        })
        (hashedAsset "favicon" "ico" {
          dir = icons;
          name = "favicon.ico";
        })
        (hashedAsset "touchicon" "png" {
          dir = icons;
          name = "touchicon.png";
        })
        (hashedAsset "touchicon144" "png" {
          dir = icons;
          name = "touchicon144.png";
        })
        (hashedAsset "icon-transparent" "png" {
          dir = icons;
          name = "icon-transparent.png";
        })
        (hashedAsset "32px" "png" {
          dir = icons;
          name = "32px.png";
        })
        (hashedAsset "40px" "png" {
          dir = icons;
          name = "40px.png";
        })
      ];
    };
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
