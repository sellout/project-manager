{pkgs, ...}: {
  project = {
    ## Manual file creation, for things that aren’t managed yet (and for modules
    ## to add files).
    file = {
    };
    ## Packages to install in the devShells that reference projectConfiguration.
    packages = [
      pkgs.nil
    ];
    projectDirectory = ../.;
  };
  programs = {
    # direnv = {
    #   envrc = {
    #     commit = false;
    #     contents = "use flake";
    #   };
    # };
    git = {
      # default is determined by whether there is a .git file/dir (and whether
      # it’s a file (worktree) or dir determines other things – like where hooks
      # are installed.
      enable = true;
      # automatically added to by
      attributes = [
      ];
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

      ];
      ignoreRevs = [
      ];
    };
  };
  # services = {
  #   garnix = {
  #   };
  #   github = {
  #     apps = {
  #       renovate = {};
  #       settings = {};
  #     };
  #     pages = "";
  #     workflows = {};
  #   };
  # };
}
