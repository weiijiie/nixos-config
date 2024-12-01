1
# {
#   inputs,
#   pkgs ? (import ../nixpkgs.nix),
#   pkgs-unstable,
#   system,
# }:
# let
#   nixvim = inputs.nixvim.legacyPackages.${system};
#   module = {
#     pkgs = pkgs-unstable;
#     module = import ../modules/nvim;
#     extraSpecialArgs = {
#       inherit inputs;
#     };
#   };
# in
# nixvim.makeNixvimWithModule module
