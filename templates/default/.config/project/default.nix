## Welcome to your project configuration!
##
## This is a Nix module (https://nixos.wiki/wiki/NixOS_modules) that is intended
## to produce both flake outputs and generated files in your project.

{lib, pkgs, ...}: {
  project = {
    name = "{{project.name}}";
    summary = "{{project.summary}}";
    ## NB: This follows the same structure as nixpkgs maintainers, so it can
    ##     contain references to that, like
    ##    `authors = [lib.maintainers.sellout];`.
    authors = [{{project.author}}];
    license = "{{project.license}}";
    ## The project.packages option allows you to install Nix packages into your
    ## environment.
    devPackages = [
      # # Adds the 'hello' command to your environment. It prints a friendly
      # # "Hello, world!" when run.
      # pkgs.hello

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, \${config.project.username}!"
      # '')

      ## language servers
      pkgs.nil # Nix
      pkgs.nodePackages.bash-language-server
    ];

    # Project Manager is pretty good at managing dotfiles. Many are handled
    # through modules for specific programs or services, but you can also create
    # them directly. The primary way to manage plain files is through
    # 'project.file'.
    file = {
      # # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    # You can also manage environment variables but you will have to manually
    # source
    #
    #  ~/.nix-profile/etc/profile.d/pm-session-vars.sh
    #
    # or
    #
    #  /etc/profiles/per-user/$USER/etc/profile.d/pm-session-vars.sh
    #
    # if you don't want to manage your shell through Project Manager.
    sessionVariables = {
      # EDITOR = "emacs";
    };

    # This value determines the Project Manager release that your configuration
    # is compatible with. This helps avoid breakage when a new Project Manager
    # release introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Project Manager. If
    # you do want to update the value, then make sure to first check the Project
    # Manager release notes.
    stateVersion = "0"; # Please read the comment before changing.
  };

  programs = {
    ## Direnv is a common tool for setting up a project-specific environment
    ## whenever you enter a directory in your project. Project Manager can
    ## create the .envrc file for you.
    direnv = {
      enable = true;
      envrc = ''
        use flake
      '';
    };

    ## FIXME: This should be enabled automatically if the configuration
    ##        determines it’s in a Git repository. Correspondingly, Mercurial or
    ##        other VCSes should be enabled automatically if the configuration
    ##        determines it’s in one of their repositories.
    git.enable = true;

    ## Let Project Manager install and manage itself.
    project-manager.enable = true;

    ## Treefmt is a meta-formatter – it runs other formatters for many languages
    ## across your repo. Enabling it makes it the formatter that Project Manager
    ## will set in your flake.
    treefmt = {
      enable = true;
      ## Turn on a Nix formatter. See
      ## https://github.com/numtide/treefmt-nix#supported-programs for a list of
      ## other supported formatters.
      programs.alejandra.enable = true;
    };
  };

  services = {
    github.enable = true;
    renovate.enable = true;
  };
}
