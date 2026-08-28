{
  programs.cargo = {
    enable = true;
    generateLockfile = {
      enable = true;
      verbose = "very";
    };
  };

  ## Needed so Git files will be generated.
  programs.git.enable = true;

  # NMT test script with assertions
  nmt.script = ''
    assertFileExists "project-files/.gitattributes"
    assertFileContent "project-files/.gitattributes" ${./gitattributes}
    ## FIXME: Can’t currently test for IFD-avoiding files
    # assertFileExists "project-files/Cargo.lock"
  '';
}
