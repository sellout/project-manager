# Configuration Example {#sec-usage-configuration}

A fresh install of Project Manager will generate a minimal `$PROJECT_ROOT/.config/project/default.nix` file containing something like

```nix
{ config, pkgs, ... }:

{
  # This value determines the Project Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Project Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Project Manager without changing this value. See
  # the Project Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = 0;

  # Let Project Manager install and manage itself.
  programs.project-manager.enable = true;
}
```

You can use this as a base for your further configurations.

::: {.note}
If you are not very familiar with the Nix language and NixOS modules
then it’s encouraged to start with small and simple changes. As you
learn you can gradually grow the configuration with confidence.
:::

As an example, let us expand the initial configuration file to also
install the htop and fortune packages, install Emacs with a few extra
packages available, and enable the user gpg-agent service.

To satisfy the above setup we should elaborate the `project.nix` file as
follows:

```nix
{ config, pkgs, ... }:

{
  # Packages that should be installed to the project profile.
  project.devPackages = [
    pkgs.htop
    pkgs.fortune
  ];

  # This value determines the Project Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Project Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Project Manager without changing this value. See
  # the Project Manager release notes for a list of state version
  # changes in each release.
  project.stateVersion = 0;

  # Let Project Manager install and manage itself.
  programs.project-manager.enable = true;

  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.nix-mode
      epkgs.magit
    ];
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
  };
}
```

- Nixpkgs packages can be installed to the development shell using
  [project.devPackages](#opt-project.devPackages).

- The option names of a program module typically start with
  `programs.<package name>`.

- Similarly, for a service module, the names start with
  `services.<package name>`. Note in some cases a package has both
  programs _and_ service options – Emacs is such an example.

To activate this configuration you can run

```shell
project-manager switch
```

or if you aren’t feeling so lucky,

```shell
project-manager build
```

which will create a `result` link to a directory containing an
activation script and the generated project directory files.
