final: prev:

let
  inherit (final) lib;

  minimums = {
    brotli = "1.2.1";
  };

  unstableBrotli = final.unstable.brotli;
in
{
  securityFixes.replacements = lib.optionals (lib.versionOlder unstableBrotli.version minimums.brotli) [
    {
      oldDependency = unstableBrotli.lib;
      newDependency = (unstableBrotli.overrideAttrs { inherit (prev.brotli) version src patches; }).lib;
    }
  ];
}
