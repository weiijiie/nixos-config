{ vimUtils, fetchFromGitHub }:
vimUtils.buildVimPlugin {
  name = "vim-colors-xcode";
  src = fetchFromGitHub {
    owner = "arzg";
    repo = "vim-colors-xcode";
    rev = "26707a8d9d17d5e4fcd3835cd6b5086c680c6fc6";
    sha256 = "sha256-+NNDVsJeg4eqcQK965Sk6E/uo00Qqn5qzy9FoU4qRUY=";
  };
  meta.homepage = "https://github.com/arzg/vim-colors-xcode";
}