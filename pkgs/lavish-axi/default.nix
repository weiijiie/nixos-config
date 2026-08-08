{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage (finalAttrs: {
  pname = "lavish-axi";
  version = "0.1.46";

  # The registry tarball ships a prebuilt dist/, so there is nothing to compile.
  # Building from the git source instead would pull the whole pnpm devDependency
  # closure to reproduce bytes that are already published.
  src = fetchurl {
    url = "https://registry.npmjs.org/lavish-axi/-/lavish-axi-${finalAttrs.version}.tgz";
    hash = "sha256-fiklREn9XrXl+ZmzTQyHB9cYAyc3UPLI9AjdetkaP3E=";
  };

  # The tarball carries no lockfile. Both files here are generated out of band and
  # must be regenerated together on a version bump: unpack the tarball, delete the
  # devDependencies block from package.json, then run
  # `npm install --package-lock-only`. Dropping devDependencies keeps the fetched
  # closure to the 8 runtime dependencies; npm ci rejects a lockfile that does not
  # satisfy package.json, which is why the trimmed manifest is vendored alongside it.
  # Patching them in place is not an option: fetchNpmDeps applies postPatch in a
  # derivation that has no node on PATH.
  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-JcyxqixWP6wF8dm3J16/50Zm93ZhTbZJSg6nyw6DRC4=";

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  meta = {
    description = "Editor that opens agent-generated HTML artifacts for human annotation and feedback";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
    platforms = lib.platforms.unix;
  };
})
