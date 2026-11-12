{
  programs.git = {
    enable = true;
    hooks.pre-push = {
      commit-by-default = true;
      text = ''
        #!/bin/sh
        exit 0
      '';
    };
    ignoreRevs = ["0000000000000000000000000000000000000000"];
  };

  xdg.dataFile = {
    "git/config".commit-by-default = true;
    "git/ignoreRevs".commit-by-default = true;
  };

  ## Git resolves these paths from the root of the working tree.
  nmt.script = ''
    assertFileExists project-files/.local/share/git/hooks/pre-push
    assertFileExists project-files/.local/share/git/ignoreRevs
    assertFileContent project-files/.local/share/git/config ${./config}
  '';
}
