{
  inputs,
  ...
}:

{
  imports = [ inputs.synix.nixosModules.nginx ];

  services.nginx = {
    enable = true;
    forceSSL = true;
    openFirewall = true;

    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
    };
  };
}
