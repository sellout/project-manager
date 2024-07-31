# Standalone installation {#sec-install-standalone}

1.  Make sure you have a working Nix installation. Specifically, make
    sure that your user is able to build and install Nix packages. For
    example, you should be able to successfully run a command like
    `nix-instantiate '<nixpkgs>' -A hello` without having to switch to
    the root user. For a multi-user install of Nix this means that your
    user must be covered by the
    [`allowed-users`](https://nixos.org/nix/manual/#conf-allowed-users)
    Nix option. On NixOS you can control this option using the
    [`nix.settings.allowed-users`](https://nixos.org/manual/nixos/stable/options.html#opt-nix.settings.allowed-users)
    system option.

2.  Add the appropriate Project Manager channel. If you are following
    Nixpkgs master or an unstable channel you can run

    ```shell
    $ nix-channel --add https://github.com/sellout/project-manager/archive/master.tar.gz project-manager
    $ nix-channel --update
    ```

    and if you follow a Nixpkgs version 24.05 channel you can run

    ```shell
    $ nix-channel --add https://github.com/sellout/project-manager/archive/release-24.05.tar.gz project-manager
    $ nix-channel --update
    ```

3.  Run the Project Manager installation command and create the first Project
    Manager generation:

    ```shell
    $ nix-shell '<project-manager>' -A install
    ```

    Once finished, Project Manager should be active and available in your
    user environment.

4.  If you don’t plan on having Project Manager manage your shell
    configuration then you must source the

    ```bash
    $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
    ```

    file in your shell configuration. Alternatively source

    ```bash
    /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh
    ```

    when managing home configuration together with system configuration.

    This file can be sourced directly by POSIX.2-like shells such as
    [Bash](https://www.gnu.org/software/bash/) or [Z
    shell](http://zsh.sourceforge.net/). [Fish](https://fishshell.com)
    users can use utilities such as
    [foreign-env](https://github.com/oh-my-fish/plugin-foreign-env) or
    [babelfish](https://github.com/bouk/babelfish).

    For example, if you use Bash then add

    ```bash
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    ```

    to your `~/.profile` file.

If instead of using channels you want to run Project Manager from a Git
checkout of the repository then you can use the
[project-manager.path](#opt-programs.project-manager.path) option to specify the absolute
path to the repository.

Once installed you can see [Using Project Manager](#ch-usage) for a more detailed
description of Project Manager and how to use it.
