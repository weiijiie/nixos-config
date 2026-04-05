{ ... }:
{
  programs.git = {
    enable = true;

    settings = {
      alias = {
        ll = "log --pretty=format:'%C(yellow)%h %C(green)%ad%Cred%d %Creset%s%Cblue [%cn]' --decorate --date=short --graph";
        l = "log --all --oneline --graph --decorate";
        cidiff = ''log --date=format:"%Y-%m-%d %H:%M" --pretty="%C(cyan)%h%Creset %C(blue)[%ad]%Creset: %C(green)%s%Creset"'';
      };

      merge = {
        conflictstyle = "diff3";
      };

      diff = {
        colorMoved = "default";
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      navigate = true;
      side-by-side = true;
      theme = "Catppuccin Macchiato";
      features = "decorations";

      decorations = {
        file-style = "lightcoral bold ul";
        file-decoration-style = "blue ul";
        file-modified-label = "#";
        hunk-header-style = "line-number syntax bold";
        hunk-header-decoration-style = "lightcoral box";
        hunk-header-line-number-style = "lightcoral ul";
        hunk-label = "";
        line-numbers-zero-style = "lightslategray";
      };
    };
  };
}
