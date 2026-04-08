{ pkgs, ... }:
{
  programs.git.settings.user = {
    email = "43085321+weiijiie@users.noreply.github.com";
    name = "Huang Weijie";
  };

  home.packages = with pkgs; [ imagemagickBig ];
}
