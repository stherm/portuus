{
  inputs,
  pkgs,
  constants,
  ...
}:

let
  c = constants.services.feuerwehr;
  site = inputs.website-ff.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.nginx.virtualHosts.${c.fqdn} = {
    root = site;
    locations."~ \\.pmtiles$".extraConfig = ''
      types { application/vnd.pmtiles pmtiles; }
    '';
  };
}
