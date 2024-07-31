# Keeping your project root safe from harm {#sec-usage-dotfiles}

To configure programs and services Project Manager must write various
things to your project directory. To prevent overwriting any existing files
when switching to a new generation, Home Manager will attempt to detect
collisions between existing files and generated files. If any such
collision is detected the activation will terminate before changing
anything on your computer.

For example, suppose you have a wonderful, painstakingly created
`$PROJECT_ROOT/.git/config` and add

```nix
{
  # …

  programs.git = {
    enable = true;
    userName = "Jane Doe";
    userEmail = "jane.doe@example.org";
  };

  # …
}
```

to your configuration. Attempting to switch to the generation will then
result in

```shell
$ project-manager switch
…
Activating checkLinkTargets
Existing file '/…/.git/config' is in the way
Please move the above files and try again
```
