# Standalone setup {#sec-flakes-standalone}

To prepare an initial Project Manager configuration for your logged in
user, you can run the Project Manager `init` command directly from its
flake.

For example, if you are using the unstable version of Nixpkgs or NixOS,
then to generate and activate a basic configuration run the command

```shell
$ nix run project-manager/master -- init --switch
```

For Nixpkgs or NixOS version 24.05 run

```shell
$ nix run project-manager/release-24.05 -- init --switch
```

This will generate a `flake.nix` and a `default.nix` file in
`./.config/project`, creating the directory if it doesn’t exist.

If you omit the `--switch` option then the activation won’t happen.
This is useful if you want to inspect and edit the configuration before
activating it.

```shell
$ nix run project-manager/$branch -- init
$ # Edit files in ~/.config/project-manager
$ nix run project-manager/$branch -- init --switch
```

Where `$branch` is one of `master` or `release-24.05`.

After the initial activation has completed successfully then building
and activating your flake-based configuration is as simple as

```shell
$ project-manager switch
```

It’s possible to override the default configuration directory, if you
want. For example,

```shell
$ nix run project-manager/$branch -- init --switch ~/hmconf
$ # And after the initial activation.
$ project-manager switch --flake ~/hmconf
```

::: {.note}
The flake inputs aren’t automatically updated by Project Manager. You need
to use the standard `nix flake update` command for that.

If you only want to update a single flake input, then the command
`nix flake lock --update-input <input>` can be used.

You can also pass flake-related options such as `--recreate-lock-file`
or `--update-input <input>` to `project-manager` when building or
switching, and these options will be forwarded to `nix build`. See the
[NixOS Wiki page](https://wiki.nixos.org/wiki/Flakes) for details.
:::
