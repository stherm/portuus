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

    appendHttpConfig = ''
      add_header Strict-Transport-Security "max-age=31536000" always;
      proxy_hide_header X-Powered-By;
    '';

    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
    };
  };
}
