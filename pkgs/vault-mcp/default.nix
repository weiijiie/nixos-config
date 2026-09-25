{
  lib,
  git,
  python3Packages,
  replaceVars,
  writers,
}:
writers.writePython3Bin "vault-mcp" {
  libraries = [ python3Packages.mcp ];
} (builtins.readFile (replaceVars ./server.py { git = lib.getExe git; }))
