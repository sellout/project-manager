# Guidelines {#sec-guidelines}

If your contribution satisfy the following rules then there is a good
chance it will be merged without too much trouble. The rules are
enforced by the Project Manager maintainers and to a lesser extent the Project
Manager CI system.

If you are uncertain how these rules affect the change you would like to
make then feel free to start a discussion in the
[#project-manager](https://webchat.oftc.net/?channels=project-manager) IRC
channel, ideally before you start developing.

## Maintain backward compatibility {#sec-guidelines-back-compat}

Your contribution shouldn’t cause another user's existing configuration
to break unless there is a good reason and the change should be
announced to the user through an
[assertion](https://nixos.org/manual/nixos/stable/index.html#sec-assertions)
or similar.

Remember that Project Manager is used in many different environments and
you should consider how your change may effect others. For example,

- Does your change work for people that don’t use NixOS? Consider
  other GNU/Linux distributions and macOS.

- Does your change work for people whose configuration is built on one
  system and deployed on another system?

## Keep forward compatibility in mind {#sec-guidelines-forward-compat}

The master branch of Project Manager tracks the unstable channel of
Nixpkgs, which may update package versions at any time. It’s therefore
important to consider how a package update may affect your code and try
to reduce the risk of breakage.

The most effective way to reduce this risk is to follow the advice in
[Add only valuable options](#sec-guidelines-valuable-options).

## Add only valuable options {#sec-guidelines-valuable-options}

When creating a new module it’s tempting to include every option
supported by the software. This is _strongly_ discouraged. Providing
many options increases maintenance burden and risk of breakage
considerably. This is why only the most [important software
options](https://github.com/NixOS/rfcs/blob/master/rfcs/0042-config-option.md#valuable-options)
should be modeled explicitly. Less important options should be
expressible through an `extraConfig` escape hatch.

A good rule of thumb for the first implementation of a module is to only
add explicit options for those settings that absolutely must be set for
the software to function correctly. It follows that a module for
software that provides sensible default values for all settings would
require no explicit options at all.

If the software uses a structured configuration format like a JSON,
YAML, INI, TOML, or even a plain list of key/value pairs then consider
using a `settings` option as described in [Nix RFC
42](https://github.com/NixOS/rfcs/blob/master/rfcs/0042-config-option.md).

## Add relevant tests {#sec-guidelines-add-tests}

If at all possible, make sure to add new tests and expand existing tests
so that your change will keep working in the future. See
[Tests](#sec-tests) for more information about the Project Manager test
suite.

All contributed code _must_ pass the test suite.

## Add relevant documentation {#sec-guidelines-module-maintainer}

Many code changes require changing the documentation as well. Module options should be documented with
[Nixpkgs-flavoured Markdown](https://nixos.org/manual/nixpkgs/unstable/#sec-contributing-markup).
All text is hosted in Project Manager's Git repository.

The HTML version of the manual containing both the module option
descriptions and the documentation of Project Manager can be generated and
opened by typing the following in a shell within a clone of the Project
Manager Git repository:

```shell
$ nix-build -A docs.html
$ xdg-open ./result/share/doc/project-manager/index.html
```

When you have made changes to a module, it’s a good idea to check that
the man page version of the module options looks good:

```shell
$ nix-build -A docs.manPages
$ man ./result/share/man/man5/project-configuration.nix.5.gz
```

<!-- prettier-ignore -->
## Add yourself as a module maintainer {#_add_yourself_as_a_module_maintainer}

Every new module _must_ include a named maintainer using the
`meta.maintainers` attribute. If you are a user of a module that
currently lacks a maintainer then please consider adopting it.

If you are present in the nixpkgs maintainer list then you can use that
entry. If you aren’t then you can add yourself to
`modules/lib/maintainers.nix` in the Project Manager project.

As a maintainer you are expected to respond to issues and
pull-requests associated with your module.

Maintainers are encouraged to join the IRC or Matrix channel and
participate when they have opportunity.

## Format your code {#sec-guidelines-code-style}

Make sure your code is formatted as described in [Code
Style](#sec-code-style). To maintain consistency throughout the project
you are encouraged to browse through existing code and adopt its style
also in new code.

## Format your commit messages {#sec-guidelines-commit-message-style}

Similar to [Format your code](#sec-guidelines-code-style) we encourage a
consistent commit message format as described in
[Commits](#sec-commit-style).

## Format your news entries {#sec-guidelines-news-style}

If your contribution includes a change that should be communicated to
users of Project Manager then you can add a news entry. The entry must be
formatted as described in [News](#sec-news).

When new modules are added a news entry should be included but you don’t
need to create this entry manually. The merging maintainer will
create the entry for you. This is to reduce the risk of merge conflicts.

## Use conditional modules and news {#sec-guidelines-conditional-modules}

Project Manager includes a number of modules that are only usable on some
of the supported platforms. The most common example of platform specific
modules are those that define systemd user services, which only works on
Linux systems.

If you add a module that’s platform specific then make sure to include
a condition in the `loadModule` function call. This will make the module
accessible only on systems where the condition evaluates to `true`.

Similarly, if you are adding a news entry then it should be shown only
to users that may find it relevant, see [News](#sec-news) for a
description of conditional news.

## Mind the license {#sec-guidelines-licensing}

The Project Manager project is covered by the MIT license and we can only
accept contributions that fall under this license, or are licensed in a
compatible way. When you contribute self written code and documentation
it’s assumed that you are doing so under the MIT license.

A potential gotcha with respect to licensing are option descriptions.
Often it’s convenient to copy from the upstream software documentation.
When this is done it’s important to verify that the license of the
upstream documentation allows redistribution under the terms of the MIT
license.

## Commits {#sec-commit-style}

The commits in your pull request should be reasonably self-contained,
that is, each commit should make sense in isolation. In particular, you
will be asked to amend any commit that introduces syntax errors or
similar problems even if they’re fixed in a later commit.

The commit messages should follow the [seven
rules](https://chris.beams.io/posts/git-commit/#seven-rules), except for
\"Capitalize the subject line\". We also ask you to include the affected
code component or module in the first line. That is, a commit message
should follow the template

    {component}: {description}

    {long description}

where `{component}` refers to the code component (or module) your change
affects, `{description}` is a very brief description of your change, and
`{long description}` is an optional clarifying description. As a rare
exception, if there is no clear component, or your change affects many
components, then the `{component}` part is optional. See
[the example commit](#ex-commit-message) for a commit message that fulfills
these requirements.

## Example commit {#ex-commit-message}

The commit
[69f8e47e9e74c8d3d060ca22e18246b7f7d988ef](https://github.com/nix-community/home-manager/commit/69f8e47e9e74c8d3d060ca22e18246b7f7d988ef)
contains the commit message

```
    starship: allow running in Emacs if vterm is used

    The vterm buffer is backed by libvterm and can handle Starship prompts
    without issues.
```

which ticks all the boxes necessary to be accepted in Project Manager.

Finally, when adding a new module, say `programs/foo.nix`, we use the
fixed commit format `foo: add module`. You can, of course, still include
a long description if you wish.

## Code Style {#sec-code-style}

The code in Project Manager is formatted by the
[alejandra](https://github.com/kamadorueda/alejandra/) tool and the formatting is
checked in the pull request tests. Run `nix fmt` inside the
project repository before submitting your pull request.

Keep lines at a reasonable width, ideally 80 characters or less. This
also applies to string literals.

We prefer `lowerCamelCase` for variable and attribute names with the
accepted exception of variables directly referencing packages in Nixpkgs
which use a hyphenated style. For example, the Project Manager option
`services.gpg-agent.enableSshSupport` references the `gpg-agent` package
in Nixpkgs.
