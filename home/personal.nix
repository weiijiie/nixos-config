{ pkgs, ... }:
{
  programs.git = {
    userEmail = "43085321+weiijiie@users.noreply.github.com";
    userName = "Huang Weijie";
  };

  home.packages = with pkgs; [ imagemagickBig ];
}
