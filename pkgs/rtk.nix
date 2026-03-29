{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "0.34.1";

  systems = {
    x86_64-linux = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-eL167Qc8nXnE9i+xEcv4NY4zwMMOfuowH7uLX9hlb/c=";
    };
    aarch64-darwin = {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-YiPXDV2bp0DRlt0IQ5qUZEkF+k3xWVQWXZm1uSTQKSc=";
    };
  };

  src = fetchurl systems.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "rtk";
  inherit version src;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  unpackPhase = ''
    tar xzf $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp rtk $out/bin/
    chmod +x $out/bin/rtk
  '';

  meta = {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.mit;
    mainProgram = "rtk";
    platforms = builtins.attrNames systems;
  };
}
