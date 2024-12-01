{ pkgs, ... }:
{
  programs = {
    kitty = {
      enable = true;
      package = pkgs.unstable.kitty;
      shellIntegration.enableZshIntegration = true;

      font = {
        name = "CaskaydiaMono Nerd Font";
        size = 14.0;
      };

      themeFile = "moonlight";

      keybindings = {
        "ctrl+c" = "copy_and_clear_or_interrupt";
        "ctrl+v" = "paste_from_clipboard";
      };

      settings = {
        dynamic_background_opacity = true;
        enable_audio_bell = true;
        scrollback_lines = 10000;
        background_opacity = "0.9";
        background_blur = 10;

        window_padding_width = 8;
        remember_window_size = "yes";
        initial_window_width = 1280;
        initial_window_height = 800;

        tab_bar_edge = "top";
        tab_bar_style = "powerline";
      };
    };
  };
}
