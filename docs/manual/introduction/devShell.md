# the `project-manager` devShell {#sec-project-manager-devShell}

One of the most powerful combinations is `self.projectConfigurations.${system}.devShells.project-manager`. This provides a shell that has a PATH and other environment that have been produced by the Project Manager configuration. If you use this environment, you can often avoid producing files into your working tree, as the executables available here may be modified to look for their files directly in the Nix store.
