<!-- prettier-ignore -->
# Why is there a collision error when switching generation? {#_why_is_there_a_collision_error_when_switching_generation}

Project Manager currently installs packages into the user environment,
precisely as if the packages were installed through `nix-env --install`.
This means that you will get a collision error if your Project Manager
configuration attempts to install a package that you already have
installed manually, that is, packages that shows up when you run
`nix-env --query`.

For example, imagine you have the `hello` package installed in your
environment

```shell
$ nix-env --query
hello-2.10
```

and your Project Manager configuration contains

```nix
project.devPackages = [ pkgs.hello ];
```

Then attempting to switch to this configuration will result in an error
similar to

```shell
$ project-manager switch
these derivations will be built:
  /nix/store/xg69wsnd1rp8xgs9qfsjal017nf0ldhm-project-manager-path.drv
[…]
Activating installPackages
replacing old ‘project-manager-path’
installing ‘project-manager-path’
building path(s) ‘/nix/store/b5c0asjz9f06l52l9812w6k39ifr49jj-project-environment’
Wide character in die at /nix/store/64jc9gd2rkbgdb4yjx3nrgc91bpjj5ky-buildenv.pl line 79.
collision between ‘/nix/store/fmwa4axzghz11cnln5absh31nbhs9lq1-project-manager-path/bin/hello’ and ‘/nix/store/c2wyl8b9p4afivpcz8jplc9kis8rj36d-hello-2.10/bin/hello’; use ‘nix-env --set-flag priority NUMBER PKGNAME’ to change the priority of one of the conflicting packages
builder for ‘/nix/store/b37x3s7pzxbasfqhaca5dqbf3pjjw0ip-project-environment.drv’ failed with exit code 2
error: build of ‘/nix/store/b37x3s7pzxbasfqhaca5dqbf3pjjw0ip-project-environment.drv’ failed
```

The solution is typically to uninstall the package from the environment
using `nix-env --uninstall` and reattempt the Project Manager generation
switch.

You could also opt to uninstall _all_ of the packages from your profile
with `nix-env --uninstall '*'`.
