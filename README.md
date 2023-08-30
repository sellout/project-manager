# Project Manager (for Nix flakes)

Like [Home Manager](https://nix-community.github.io/home-manager/), but for repositories.

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

Project Manager encourages you to put configuration in `$PROJECT_ROOT/.config` (akin to the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)). But you don’t have to – you can put them anywhere you like. The organization is up to you.

Other config files generally need to be in particular locations that the tools know to look in, and rarely do all of those places fit together in a coherent repo.

Granted, after generation, those config files still exist in those locations, but 1. they’re often not committed the repository and 2. they are ignored by the VCS (and there are many other tools that _also_ ignore VCS-ignored files, so in some ways the generated configs are still invisible.

## Usage

For now, after cloning, etc. run

```bash
project-manager switch --flake .
```

to regenerate all the files you need.

For this to do anything, you need to add a `projectConfigurations.${system}` output to your flake. This project has one itself, and you can view the contents in [.config/project.nix](./.config/project.nix).

## Credit

This is more than inspired by Home Manager, it’s basically a hacked-up copy (for now). That should change to _depend on_ Home Manager for what it can and to do everything else its own way. But this is a pre-pre-alpha at the moment, so it’s hack city.
