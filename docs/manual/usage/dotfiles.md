# Keeping your project root safe from harm {#sec-usage-dotfiles}

To configure programs and services Project Manager must write various things to your project directory. Project Manager will attempt to detect collisions with existing files, but this can be difficult. Whereas Home Manager can rely on symlinks to identify files that have been produced during activation, Project Manager can’t always do this. Files with [“repository” persistence](#opt-project.file._name_.minimum-persistence) must be either hard links or copies (if the project is on a different volume than the Nix store). Project Manager must assume these files can be overwritten. This is why it’s important to ensure that changes are stashed or committed before running `project-manager switch`.

If there are collisions between existing files and files with “worktree” persistence, these will cause Project manager to terminate before changing _any_ files. (Files with “store” persistence don’t exist in the worktree and thus can never prevent switching.)

For example, suppose you have a wonderful, painstakingly created `$PROJECT_ROOT/.git/config` and add

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

to your configuration. Attempting to switch to the generation will then result in

```shell
$ project-manager switch
…
Activating checkLinkTargets
Existing file '/…/.git/config' is in the way
Please move the above files and try again
```
