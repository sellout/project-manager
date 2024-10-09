# Installing Project Manager {#ch-installation}

**NB**: Project Manager doesn’t need to be installed outside of the projects it is used in. In most projects that use Project Manager, `nix develop` (or maybe `nix develop .#project-manager`) should put you into a shell that makes `project-manager` available to you. The exception to this is when you are [adding Project Manager to a project](#ch-quick-start).

That said, it can be useful to have Project Manager installed more widely. Currently this can only be done via a flake. This snippet includes examples for nix-darwin, Home Manager, and NixOS. You do not need to include all of them.

```nix
{
  outputs = {home-manager, nix-darwin, nixpkgs, project-manager, self ...}: let
    system = "x86_64-linux"; # or another system
    pkgs = import nixpkgs {
      inherit system;
      overlays = [project-manager.overlays.default];
    };
  {
    darwinConfigurations."host" = nix-darwin.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ({pkgs, ...}: {
          environment.systemPackages = [pkgs.project-manager];
        })
      ];
    };

    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ({pkgs, ...}: {
          home.packages = [pkgs.project-manager];
        })
      ];
    };

    nixosConfigurations."host" = nixpkgs.lib.nixosSystem {
      inherit pkgs system;
      modules = [
        ({pkgs, ...}: {
          environment.systemPackages = [pkgs.project-manager];
        })
      ];
    };
  };

  inputs.project-manager.url = "github:sellout/project-manager";
}
```
