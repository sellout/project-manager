# Using Project Manager {#ch-usage}

Your use of Project Manager is centered around the configuration file,
which is typically found at `$PROJECT_ROOT/.config/project/default.nix` in the
standard installation or `$PROJECT_ROOT/flake.nix` in a Nix
flake based installation.

This configuration file can be _built_ and _activated_.

Building a configuration produces a directory in the Nix store that
has all files and programs that should be available in your project
directory and Nix project profile, respectively. The build step also checks
that the configuration is valid and it will fail with an error if you,
for example, assign a value to an option that doesn’t exist or assign a
value of the wrong type. Some modules also have custom assertions that
perform more detailed, module specific, checks.

Concretely, if your configuration has

```nix
programs.git.enable = "yes";
```

then building it, for example using `project-manager build`, will result in
an error message saying something like

```console
$ project-manager build
error: A definition for option `programs.git.enable' is not of type `boolean'. Definition values:
- In `/.../.config/project/default.nix': "yes"
(use '--show-trace' to show detailed location information)
```

The message indicates that you must give a Boolean value for this
option, that is, either `true` or `false`. The documentation of each
option will state the expected type, for
[programs.git.enable](#opt-programs.git.enable) you will see "Type: boolean". You
there also find information about the default value and a description of
the option. You can find the complete option documentation in
[Project Manager Configuration Options](#ch-options) or directly in the terminal by running

```shell
man project-configuration.nix
```

Once a configuration is successfully built, it can be activated. The
activation performs the steps necessary to make the files, programs, and
services available in your user environment. The `project-manager switch`
command performs a combined build and activation.

```{=include=} sections
usage/configuration.md
usage/rollbacks.md
usage/dotfiles.md
usage/updating.md
```
