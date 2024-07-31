# Writing Project Manager Modules {#ch-writing-modules}

The module system in Project Manager is based entirely on the NixOS module
system so we will here only highlight aspects that are specific for Project
Manager. For information about the module system as such please refer to
the [Writing NixOS
Modules](https://nixos.org/nixos/manual/index.html#sec-writing-modules)
chapter of the NixOS manual.

Overall the basic option types are the same in Project Manager as Home Manager. There are some extra options provided in the file-type submodule.

```{=include=} sections
writing-modules/types.md
```
