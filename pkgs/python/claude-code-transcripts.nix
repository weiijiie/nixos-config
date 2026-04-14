{
  python3Packages,
  fetchFromGitHub,
  lib,
}:
python3Packages.buildPythonApplication {
  pname = "claude-code-transcripts";
  version = "0.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "simonw";
    repo = "claude-code-transcripts";
    tag = "0.6";
    hash = "sha256-MCs8B00K/D4rO4kWi3PlATo44rvBlQWYF7gU2c5tFrk=";
  };

  build-system = [ python3Packages.uv-build ];

  dependencies = with python3Packages; [
    click
    click-default-group
    httpx
    jinja2
    markdown
    questionary
  ];

  # Tests require network access and snapshot fixtures
  doCheck = false;

  meta = {
    description = "Convert Claude Code session files to HTML transcripts";
    homepage = "https://github.com/simonw/claude-code-transcripts";
    license = lib.licenses.asl20;
    mainProgram = "claude-code-transcripts";
  };
}
