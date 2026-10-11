{
  services = {
    flakestry.enable = true;
    github.enable = true;
  };

  nmt.script = ''
    assertFileExists "project-files/.github/workflows/flakestry-publish.yml"
    assertFileContent "project-files/.github/workflows/flakestry-publish.yml" \
      ${./.github/workflows/flakestry-publish.yml}
  '';
}
