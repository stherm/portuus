{ lib, pkgs }:
files:

let
  icons = import ./icon-dir.nix { inherit lib pkgs; } files;
in
lib.mapAttrs' (
  file: _:
  lib.nameValuePair "= /${file}" {
    alias = "${icons}/${file}";
    extraConfig = ''
      add_header Cache-Control "public, max-age=86400";
    '';
  }
) files
