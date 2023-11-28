[![built with garnix](https://img.shields.io/endpoint?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fsellout%2Fproject-manager%3Fbranch%3Dmain)](https://garnix.io)

# Project Manager (for Nix flakes)

Like [Home Manager](https://nix-community.github.io/home-manager/), but for repositories.

See [the manual](https://sellout.github.io/project-manager/).

## What?

Project Manager helps tame the various configurations that clutter every repository. After a while, you end up with files scattered around, unrelated to anything, that are used by various tools or online services to support your project.

Project Manager allows you to make all of these part of your Nix configuration, unifying formats and hiding the results when possible. Fewer files end up committed to the repository. Ones that are have a clear provenance, and all of those files can now be programmed, rather than having to duplicate data in various places.

This will also help you manage tooling like git hooks that are explicitly difficult to manage automatically.

## Why?

### organization

Normally config files are scattered around your repository, without any connection to what commands they might affect. This allows you to associate configurations with the programs and services that they are for. Making the layout of the repository easier to understand and more discoverable.

This is probably the biggest point here – your configurations can now effectively have a narrative based around the structure of your flake, making for easier on-boarding of new contributors. Or even just reminding yourself why you made that change last week …

### programmable configurations

Since the dawn of Unix epoch, configuration languages have grown to become programmable, despite the best efforts of their designers. Unfortunately, this generally results in various shortcomings and awkwardness. Project Manager gives you that programmability in a couple ways. One is that the configs in your repo can be templates, populated by Nix. But, to go even farther, the configs can be arbitrary Nix expressions that produce a static config. And, given Nix’s various other tools, you can do all sorts of crazy stuff, like write all your configs in Dhall or YAML, and then generate TOML and JSON from them as needed.

### decluttered repositories

Project Manager encourages you to put configuration in `$PROJECT_ROOT/.config/project/` (akin to the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)). But you don’t have to – you can put it anywhere you like. The organization is up to you.

Other config files generally need to be in particular locations that the tools know to look in, and rarely do all of those places fit together in a coherent repo.

Granted, after generation, those config files still exist in those locations, but 1. they’re often not committed the repository and 2. they are ignored by the VCS (and there are many other tools that _also_ ignore VCS-ignored files, so in some ways the generated configs are still invisible.

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
- `packages.path` contains all of the packages referenced by the project configuration, it is used in devShells, etc. to make sure the right versions of the right commands are available. You might use it directly to add the packages to another derivation
- `packages.sessionVariables` sets up the shell environment variables referenced by the project configuration.

#### `checks`

Project manager provides various checks based on your configuration. E.g.,

- `checks.formatter` verifies that a Project Manager-configured formatter (see below) agrees with the current state of the code and
- `checks.project-manager-files` verifies that the “repository”-persisted files are all up-to-date.

You can pick and choose, or just include them all via something like

```nix
checks = self.projectConfigurations.${system}.checks self // {
  ## more checks
};
```

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

You generally shouldn’t need to use the `Except` variants, because modules that rely on Project Manager-generated files _should_ be loading them from the store (regardless of their persistence), but if you have explicitly generated additional files, it can be easier to whitelist them with `Except` than to wrap the various tools.

## Concepts

### persistence

One of the ideas underlying the decluttering here is that of “persistence”. _How_ do different files persist? There are three levels, from strongest to weakest:

#### repository

This is what we generally see in projects – files committed to a repo that are always there. All of your non-generated files are persisted this way, and traditionally, many generated files are too. We still need to commit generated files, but generally only ones that are used for services that process the repo without running anything within it. The generated files in this level are usually represented by hard links to the Nix store, but sometimes copies[^1].

#### worktree

These are files that _don’t_ get committed (and thus are ignored by the VCS tooling), but still need to live in the worktree. These are often files needed by the build, formatters, etc. – configuration that is useful while working on a repo. These are generally represented as symlinks, but may be hard links or copies in some cases[^1]. E.g., .gitignore isn’t a symlink, because `git` can’t process it if it is.

[^1]: We try to use hard links instead of copies whenever possible. However, we need to use copies when the Nix store is on a separate volume from the worktree. In the case of “repository” persistence, it’s also the case that any files updated by a checkout will be copies until `project-manager` is run again (which can be done in a `post-checkout` hook, avoiding those copies.

#### store

This is the ideal – these are files that are only linked into the project _while_ some operation is running. The code generation is done up-front, but only resides in the Nix store unless running. Since they only exist temporarily, it matters less (from the user’s perspective) how these are implemented, so we optimize for performance. If the store and worktree are both on the same volume, we use a hard link. If they’re not, we use a symlink unless that’s broken, in which case a copy.

---

Users have control over each file’s persistence, but you generally don’t have to worry about persistence in practice. Modules are careful to default to the weakest persistence that has the desired properties. When explicitly creating `project.file`s, it defaults to “repository”, because that should work in all cases, even though it may often be stronger than necessary.

Finally, there is a `project.commit-by-default` (which defaults to `false`) and a `commit-by-default` for each file (which defaults to `project.commit-by-default`). These can be used to override the `minimum-persistence` values and commit files that otherwise wouldn’t be. It can be very helpful to set `project.commit-by-default = true` when you have non-Nix-using contributors who use tooling that expects these files to exist outside of a Nix environment.

## Credit

This is more than inspired by Home Manager, it’s basically a hacked-up copy (for now). That should change to _depend on_ Home Manager for what it can and to do everything else its own way. But this is a pre-pre-alpha at the moment, so it’s hack city.
