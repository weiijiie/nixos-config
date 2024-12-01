{
  plugins = {
    lsp-format = {
      enable = true;
      lspServersToEnable = "all";
    };

    lsp = {
      enable = true;

      servers = {
        gopls = {
          enable = true;
          autostart = true;
        };

        clangd = {
          enable = true;
          autostart = true;
        };

        rust_analyzer = {
          enable = true;
          autostart = true;
          installCargo = false;
          installRustc = false;
        };

        eslint = {
          enable = true;
          autostart = true;
        };

        # fast python linter
        ruff = {
          enable = true;
          autostart = true;
        };

        terraformls = {
          enable = true;
          autostart = true;
        };

        bashls = {
          enable = true;
          autostart = true;
        };

        nixd = {
          enable = true;
          autostart = true;
        };
      };
    };
  };
}
