# This file defines overlays
{ inputs, ... }:
{
  # Brings our custom packages from the 'pkgs' directory under
  # `pkgs.custom`
  custom = final: _prev: {
    custom = import ../pkgs {
      inherit inputs;
      pkgs = final;
    };
  };

  # Brings our inline shell scripts from the 'scripts' directory under
  # `pkgs.scripts`. Not exposed as flake packages.
  scripts = final: _prev: {
    scripts = import ../scripts { pkgs = final; };
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    # Django's test suite is flaky under parallel execution on Linux:
    # `test_media_root_pathlib` intermittently fails with a FileNotFoundError
    # (a test-isolation bug — nixpkgs already forces --parallel=1 on Darwin).
    # This broke `mcp-nixos` builds, since django is only a transitive test
    # dependency here (via moto/pytest-django). We never use django's own test
    # results, so skip its check phase entirely for determinism and speed.
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pyfinal: pyprev: {
        django = pyprev.django.overridePythonAttrs (_: {
          doCheck = false;
        });
      })
    ];

    # mcp-nixos 2.4.3's build-time test suite has a brittle test
    # (test_read_text_file) that asserts "Error" is absent from a file it
    # reads, but fails when the file's contents legitimately contain that
    # word in the Nix sandbox. We only use mcp-nixos as an MCP server, so
    # deselect that test (it already disables test_valid_channel upstream).
    mcp-nixos = prev.mcp-nixos.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_read_text_file" ];
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  llm-agents = inputs.llm-agents.overlays.default;
}
