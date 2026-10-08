{ config, pkgs, ... }:

let
  token = config.sops.secrets."portuus-bot/token".path;

  credentialHelper = pkgs.writeShellScript "git-credential-portuus" ''
    [ "$1" = get ] || exit 0
    [ -r ${token} ] || exit 0
    echo username=portuus-bot
    echo "password=$(cat ${token})"
  '';
in
{
  sops.secrets."portuus-bot/token" = {
    owner = "github-runner-portuus";
    mode = "0400";
  };

  programs.git = {
    enable = true;
    config.credential."https://git.portuus.de".helper = "${credentialHelper}";
  };
}
