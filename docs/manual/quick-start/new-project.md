# New Project {#sec-new-project}

To create a new project from scratch, run the following command :

```bash
nix run github:sellout/project-manager -- init my-new-project --switch
```

This will create a new directory called “my-new-project” in the current directory, create a flake and project configuration (.config/project/default.nix) in that directory, and populate it with files as dictated by the project configuration.

See [§Configuration](#sec-usage-configuration) for where to go from here.
