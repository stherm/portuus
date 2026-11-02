{ pkgs, ... }:

{
  system.replaceDependencies.replacements = pkgs.securityFixes.replacements;
}
