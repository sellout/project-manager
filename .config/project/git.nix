{...}: {
  programs.git = {
    # default is determined by whether there is a .git file/dir (and whether
    # it’s a file (worktree) or dir determines other things – like where hooks
    # are installed.
    enable = true;
    # automatically added to by
    config = {
      commit.template = {
        contents = "";
        path = ".config/git/template/commit.txt";
      };
    };
    hooks = {
      # post-commit = {
      #   auto-install = true;
      #   content = "";
      # };
    };
    ignores = [
      # Nix build
      "/result"
      "/source"
    ];
    ignoreRevs = [
      "85aa90127b474729fecedfbfce566c8db1760cd1" # formatting
    ];
  };
}
