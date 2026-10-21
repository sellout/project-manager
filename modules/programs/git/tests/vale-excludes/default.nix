{
  config,
  lib,
  pkgs,
  ...
}: {
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

  ## Files in the store aren’t in the worktree for Vale to see, so commit these
  ## to check that they’re excluded.
  xdg.dataFile = {
    "git/config".commit-by-default = true;
    "git/ignoreRevs".commit-by-default = true;
  };

  ## Sorted so this doesn’t depend on the order in which modules merge.
  nmt.script = ''
    assertFileContent \
      ${pkgs.writeText "vale-excludes" (lib.concatLines (lib.sort lib.lessThan config.programs.vale.excludes))} \
      ${./excludes}
  '';
}
