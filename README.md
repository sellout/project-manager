# Project Manager (for Nix flakes)

[![built with garnix](https://img.shields.io/endpoint?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fsellout%2Fproject-manager)](https://garnix.io/repo/sellout/project-manager)
[![Nix CI](https://nix-ci.com/badge/gh:sellout:project-manager)](https://nix-ci.com/gh:sellout:project-manager)

Like [Home Manager](https://nix-community.github.io/home-manager/), but for repositories.

This file is primarily for contributors. See [the manual](https://sellout.github.io/project-manager/) for user documentation (including how to write modules) or join [the Matrix room](https://matrix.to/#/%23project-manager:matrix.org) to discuss any aspect of Project Manager.

## What?

Project Manager helps tame the various configurations that clutter every repository. After a while, you end up with files scattered around, unrelated to anything, that are used by various tools or online services to support your project.

Project Manager allows you to make all these part of your Nix configuration, unifying formats and hiding the results when possible. Fewer files end up committed to the repository. Ones that are have a clear provenance, and all those files can now be programmed, rather than having to duplicate data in various places.

This will also help you manage tooling like git hooks that are explicitly difficult to manage automatically.

## Why?

### organization

Normally configuration files are scattered around your repository, without any connection to what commands they might affect. This allows you to associate configurations with the programs and services that they’re for. Making the layout of the repository easier to understand and more discoverable.

This is probably the biggest point here – your configurations can now effectively have a narrative based around the structure of your flake, making for easier on-boarding of new contributors. Or even just reminding yourself why you made that change last week …

### programmable configurations

Since the dawn of Unix epoch, configuration languages have grown to become programmable, despite the best efforts of their designers. This results in various shortcomings and awkwardness. Project Manager gives you that programmability in a couple ways. One is that the configurations in your repository can be templates, populated by Nix. But, to go even farther, the configurations can be arbitrary Nix expressions that produce a static configuration. And, given Nix’s various other tools, you can do all sorts of crazy stuff, like write all your configurations in Dhall or YAML, and then generate TOML and JSON from them as needed.

### decluttered repositories

Project Manager encourages you to put configuration in `$PROJECT_ROOT/.config/project/` (akin to the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)). But you don’t have to – you can put it anywhere you like. The organization is up to you.

Other configuration files need to be in particular locations that the tools know to look in, and rarely do all those places fit together in a coherent repository.

Granted, after generation, those configuration files still exist in those locations, but 1. they’re often not committed the repository and 2. they’re ignored by the version control system (VCS). And there are many other tools that _also_ ignore VCS-ignored files, so in some ways the generated configurations are still invisible.

## Usage

For now, after cloning, etc. run

```bash
project-manager switch
```

to regenerate all the files you need.

For this to do anything, you need to add a `projectConfigurations.${system}` output to your flake. This project has one itself, and you can view the contents in [.config/project](./.config/project/default.nix).

### configuration attributes

Once you define your `projectConfigurations`, there are a number of helpful attributes to take advantage of

#### `packages`

- `packages.activation` – rarely used directly, this is the derivation behind `project-manager switch`. It’s what sets up your generated environment.
- `packages.path` has all the packages referenced by the project configuration, it’s used in `devShells`, etc. to make sure the right versions of the right commands are available. You might use it directly to add the packages to another derivation
- `packages.sessionVariables` sets up the shell environment variables referenced by the project configuration.

#### `checks`

Project manager provides various checks based on your configuration. For example,

- `checks.formatter` verifies that a Project Manager-configured formatter (see below) agrees with the current state of the code and
- `checks.project-manager-files` verifies that the “repository”-persisted files are all up-to-date.

You can pick and choose, or just include them all via something like

```nix
checks = self.projectConfigurations.${system}.checks // {
  ## more checks
};
```

There are two other attribute sets, `sandboxedChecks` and `unsandboxedChecks`, that partition `checks`. I recommend having `nixConfig.sandbox = true` in your flake and using `checks` unless you know you have enabled some modules (like Vale) that fail in the sandbox.

If that's the case, you have a couple options. You can either

- use `sandboxedChecks` in the flake to only include sandboxed ones in `nix flake check` or
- weaken `nixConfig.sandbox` to `"relaxed"`, which will allow explicitly unsandboxed derivations (`__noChroot = true`) to run, but keep the others sandboxed.

and run `nix --no-sandbox develop .#unsandboxedChecks` to check the others.

#### `devShell`

A shell derivation that provides everything configured in your project configuration.

The following will set it up as the default shell. it can also be overridden to use as a basis of various shells.

```nix
devShells = self.projectConfigurations.${system}.devShells // {
  ## more devShells
};
```

#### `formatter`

You can choose to configure the formatter through Project Manager. (see [the treefmt module](./modules/programs/treefmt.nix) for an example. One benefit of doing it this way is that you get a check included.

```nix
formatter = self.projectConfigurations.${system}.formatter;
```

#### (`clean`|`filter`)`RepositoryPersisted`(`Except`)?

Various source filters that clean up files generated by Project Manager that have been committed.

```nix
src = self.projectConfigurations.${system}.cleanRepositoryPersisted ./.;
```

You shouldn’t need to use the `Except` variants, because modules that rely on Project Manager-generated files _should_ be loading them from the store (regardless of their persistence), but if you have explicitly generated additional files, it can be easier to whitelist them with `Except` than to wrap the various tools.

## Concepts

### persistence

One of the ideas underlying the decluttering here is that of “persistence”. _How_ do different files persist? There are three levels, from strongest to weakest:

#### `repository`

This is what we see in projects – files committed to a repository that are always there. All your non-generated files are persisted this way, and traditionally, many generated files are too. We still need to commit generated files, but only ones that are used for services that process the repository without running anything within it. The generated files in this level are usually represented by hard links to the Nix store, but sometimes copies[^1].

#### `worktree`

These are files that _don’t_ get committed (and thus are ignored by the VCS tooling), but still need to live in the working tree. These are often files needed by the build, formatters, etc. – configuration that’s useful while working on a repository. These are represented as symlinks, but may be hard links or copies sometimes[^1]. For example, .gitignore isn’t a symlink, because `git` can’t process it if it is.

[^1]: We try to use hard links instead of copies whenever possible. However, we need to use copies when the Nix store is on a separate volume from the working tree. In the case of “repository” persistence, it’s also the case that any files updated by a checkout will be copies until `project-manager` is run again (which can be done in a `post-checkout` hook, avoiding those copies.

#### `store`

This is the ideal – these are files that are only linked into the project _while_ some operation is running. The code generation is done up-front, but only resides in the Nix store unless running. Since they only exist temporarily, it matters less (from the user’s perspective) how these are implemented, so we optimize for performance. If the store and working tree are both on the same volume, we use a hard link. If they’re not, we use a symlink unless that’s broken, in which case a copy.

---

Users have control over each file’s persistence, but you don’t have to worry about persistence in practice. Modules are careful to default to the weakest persistence that has the desired properties. When explicitly creating `project.file`s, it defaults to “repository”, because that should work in all cases, even though it may often be stronger than necessary.

Finally, there is a `project.commit-by-default` (which defaults to `false`) and a `commit-by-default` for each file (which defaults to `project.commit-by-default`). These can be used to override the `minimum-persistence` values and commit files that otherwise wouldn’t be. It can be helpful to set `project.commit-by-default = true` when you have non-Nix-using contributors who use tooling that expects these files to exist outside of a Nix environment.

## Comparisons

There are a couple other projects that apply Nix modules to your flakes. However, they differ from Project Manager in various ways, and so far I believe they’re all complementary. One thing that could be improved is making it easier to share different modules between the systems.

### [devenv](https://devenv.sh/)

This is specifically a way to produce `devShells` using Nix modules. Project Manager also produces `devShells`, but it does it incidentally to overall project configuration. For example., there is the `project-manager` devShell that contains all the inputs and environment from the configuration of the project, which you may or may not want to expose via various `devShells` in your environment.

Project Manager should probably have a devenv module for defining `devShells`.

### [Flake Parts](https://flake.parts/)

This is at the other end of the spectrum and is _maybe_ more of a competitor to Project Manager. Flake Parts turns your entire flake into a module. But its purpose is to generate the flake itself. While Project Manager does generate some flake outputs, it also generates a lot of things outside of the flake (like formatter configurations, online service configurations, etc.). The tradeoff here is that (like many other tools, including Home Manager and NixOS) Project Manager has an activation package that needs to be run, while Flake Parts is pure.

Flake Parts should probably have a Project Manager module for defining `projectConfiguration` outputs.

## Credit

This is more than inspired by Home Manager, it’s basically a hacked-up copy (for now). That should change to _depend on_ Home Manager for what it can and to do everything else its own way. But this is a pre-pre-alpha at the moment, so it’s hack city.
