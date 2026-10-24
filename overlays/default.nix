{ inputs, ... }:

{
  synix-packages = final: prev: { synix = inputs.synix.overlays.additions final prev; };

  local-packages = final: prev: { local = import ../pkgs { pkgs = final; }; };

  modifications =
    final: prev:
    let
      files = [
      ];
      imports = builtins.map (f: import f final prev) files;
    in
    builtins.foldl' (a: b: a // b) { } imports // inputs.synix.overlays.modifications final prev;

  old-stable-packages = final: prev: {
    old-stable = import inputs.nixpkgs-old-stable {
      inherit (prev.stdenv.hostPlatform) system;
      inherit (prev) config;
    };
  };

  unstable-packages = final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (prev.stdenv.hostPlatform) system;
      inherit (prev) config;
    };
  };
}
