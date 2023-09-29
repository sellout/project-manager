# Example project configuration

This is not only an example, but the actual project configuration used by this repo. See [the top-level README](../README.md) for more about what Project Manager is and how to use it.

The key file here is [default.nix](./default.nix), which is explicitly imported by [the top-level flake.nix](../../flake.nix:). Everything else in this directory is imported by default.nix. default.nix contains the general project metadata, and the other files contain configuration for various other programs and services that this repository relies on.

This organization isn’t required. All of these files could be combined, or perhaps just one or two large configurations extracted from default.nix. default.nix itself can be anywhere in your repo and named anything, so long as it’s referenced correctly in `projectConfigurations` in flake.nix.
