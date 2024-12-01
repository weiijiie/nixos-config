{
  plugins.treesitter = {
    enable = true;
    settings = {
      indent.enable = true;
      highlight.enable = true;

      incremental_selection = {
        enable = true;
        keymaps = {
          init_selection = false;
          node_decremental = "grm";
          node_incremental = "grn";
          scope_incremental = "grc";
        };
      };

      ensure_installed = [
        "bash"
        "c"
        "c_sharp"
        "cmake"
        "comment"
        "cpp"
        "css"
        "csv"
        "dockerfile"
        "editorconfig"
        "git_config"
        "git_rebase"
        "gitattributes"
        "gitcommit"
        "gitignore"
        "go"
        "gomod"
        "gosum"
        "gotmpl"
        "graphql"
        "hcl"
        "html"
        "java"
        "javascript"
        "jq"
        "jsdoc"
        "json"
        "json5"
        "jsonnet"
        "latex"
        "lua"
        "make"
        "markdown"
        "nix"
        "proto"
        "python"
        "regex"
        "ruby"
        "rust"
        "sql"
        "svelte"
        "terraform"
        "toml"
        "typescript"
        "xml"
        "yaml"
        "zig"
      ];
    };
  };
}
