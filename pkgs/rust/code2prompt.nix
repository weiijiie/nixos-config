{
  pkgs,
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "code2prompt";
  version = "3.0.2";

  src = fetchFromGitHub {
    owner = "mufeedvh";
    repo = "code2prompt";
    rev = "v${version}";
    hash = "sha256-9YbsrbExRFbsEz2GifklmUGp3YlsEUOi25+P5vPK8fs=";
  };

  cargoHash = "sha256-cAaGQ28bMLoBzzcTpltiMmFlSimcm3xwiS1+MbRp37s=";

  checkType = "debug";

  nativeBuildInputs = [
    pkgs.perl
    pkg-config
  ];

  buildInputs =
    [
      openssl
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.AppKit
    ];

  meta = {
    description = "A CLI tool that converts your codebase into a single LLM prompt with a source tree, prompt templating, and token counting";
    homepage = "https://github.com/mufeedvh/code2prompt";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ heisfer ];
    mainProgram = "code2prompt";
  };
}
