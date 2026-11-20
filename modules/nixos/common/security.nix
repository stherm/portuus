{ pkgs, ... }:

{
  system.replaceDependencies.replacements = pkgs.securityFixes.replacements;

  boot = {
    blacklistedKernelModules = [ "sctp" ];
    extraModprobeConfig = ''
      install sctp ${pkgs.coreutils}/bin/false
    '';
  };
}
