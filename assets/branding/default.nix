let
  colors = {
    navy = "#02192e";
    surface = "#0a2740";
    surface-hover = "#10324f";
    border = "#1d4363";
    text = "#edf3f6";
    muted = "#a8c0cc";
    blue-50 = "#edf3f6";
    blue-100 = "#d6e4eb";
    blue-200 = "#bfd5e0";
    blue-300 = "#a8c7d6";
    blue-400 = "#92b8cb";
    blue-450 = "#7aa8bf";
    blue-500 = "#6297b2";
    blue-600 = "#4c8099";
    blue-700 = "#3d677b";
    blue-800 = "#2e4e5d";
    blue-900 = "#1f3540";
    blue-950 = "#0f1c22";
  };

  hexByte = hex: (builtins.fromTOML "v = 0x${hex}").v;

  rgb =
    color:
    builtins.concatStringsSep " " (
      map (i: toString (hexByte (builtins.substring i 2 color))) [
        1
        3
        5
      ]
    );

  cssVariables =
    ":root {\n"
    + builtins.concatStringsSep "" (
      map (name: "  --portuus-${name}: ${colors.${name}};\n  --portuus-${name}-rgb: ${rgb colors.${name}};\n") (
        builtins.attrNames colors
      )
    )
    + "}\n";
in
{
  inherit colors rgb cssVariables;
  primary = colors.blue-600;
  accent = colors.blue-400;
  logo = ./logo.svg;
  png = ./png;
}
