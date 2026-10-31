{ lib, pkgs }:
files:

let
  branding = import ./.;

  render =
    file: size:
    let
      s = toString size;
      inner = toString (size * 4 / 5);
    in
    ''
      mkdir -p "$(dirname "$out/${file}")"
    ''
    + (
      if lib.hasSuffix ".ico" file then
        ''
          magick $src -define icon:auto-resize=16,32,48 "$out/${file}"
        ''
      else if lib.hasInfix "maskable" file then
        ''
          magick $src -resize ${inner}x${inner} -background '${branding.colors.navy}' -gravity center -extent ${s}x${s} "$out/${file}"
        ''
      else
        ''
          magick $src -resize ${s}x${s} "$out/${file}"
        ''
    );
in
pkgs.runCommand "portuus-icons" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
  src=${./png/logo-1024.png}
  mkdir $out
  ${lib.concatStrings (lib.mapAttrsToList render files)}
''
