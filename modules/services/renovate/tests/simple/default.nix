{
  ## With no additional settings, we get a bare-bones Renovate config.
  services.renovate.enable = true;

  nmt.script = ''
    assertFileExists "project-files/renovate.json"
    assertFileContent "project-files/renovate.json" ${./renovate.json}
  '';
}
