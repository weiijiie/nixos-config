{
  lib,
  git,
  python3,
  replaceVars,
  runCommand,
  writers,
}:
let
  source = replaceVars ./vault_tools.py { git = lib.getExe git; };

  vault-tools = writers.writePython3Bin "vault-tools" {
    libraries = [ python3.pkgs.mcp ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile source);
in
vault-tools.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    tests =
      runCommand "vault-tools-tests"
        {
          nativeBuildInputs = [
            (python3.withPackages (ps: [
              ps.mcp
              ps.pytest
            ]))
          ];
        }
        ''
          cp ${source} vault_tools.py
          cp ${./test_vault_tools.py} test_vault_tools.py
          HOME=$TMPDIR pytest -q -p no:cacheprovider
          touch $out
        '';
  };
})
