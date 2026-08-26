# Obsidian's official headless CLI (`ob`): Sync and Publish without the app.
#
# The npm tarball ships a bundled cli.js and no lockfile; package-lock.json
# here is generated from its two declared dependencies so the build works
# offline. better-sqlite3 is a native addon: its prebuilt-binary download
# fails in the sandbox and node-gyp compiles it instead, which is the point.
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  python3,
}:
buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.14";

  nodejs = nodejs_22;

  src = fetchurl {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-73UpjtOjVtyypN6Yxu/hCyrGSwBVYAcRi2rHBTXnMVY=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-VmZj3GWaV24MX3MXVNYz/27gy3Lv4RfgioVjSdRbjtY=";

  nativeBuildInputs = [ python3 ];

  # The tarball has no build script.
  dontNpmBuild = true;

  meta = {
    description = "Official Obsidian CLI for headless Sync and Publish";
    homepage = "https://obsidian.md/help/sync/headless";
    license = lib.licenses.unfree;
    mainProgram = "ob";
    platforms = lib.platforms.linux;
  };
}
