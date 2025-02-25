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
rustPlatform.buildRustPackage {
  pname = "code2prompt";
  version = "20250221";

  src = fetchFromGitHub {
    owner = "mufeedvh";
    repo = "code2prompt";
    rev = "a1eacf0e3f7a9fc7a252e71bac3dcaa189cf46a5";
    hash = "sha256-sdZO8YvDZsGYUAy9NqEK16jJtV3pTcXjyRppfBNgcCs=";
  };

  cargoHash = "sha256-2kCTgawmrvsJcudXamkVS8BKx3uh+9A9ikYUkRpWqVs=";

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
