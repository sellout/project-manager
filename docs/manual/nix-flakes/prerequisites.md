# Prerequisites {#sec-flakes-prerequisites}

- Install Nix 2.4 or later, or have it in `nix-shell`.

- Enable experimental features `nix-command` and `flakes`.

  - When using NixOS, add the following to your `configuration.nix`
    and rebuild your system.

    ```nix
    nix = {
      package = pkgs.nixFlakes;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
    ```

  - If you aren’t using NixOS, add the following to `nix.conf`
    (located at `~/.config/nix/` or `/etc/nix/nix.conf`).

    ```bash
    experimental-features = nix-command flakes
    ```

    You may need to restart the Nix daemon with, for example,
    `sudo systemctl restart nix-daemon.service`.

  - You can also enable flakes on a per-command basis with
    the following extra flags to `nix` and `project-manager`:

    ```shell
    $ nix --extra-experimental-features "nix-command flakes" <sub-commands>
    $ project-manager --extra-experimental-features "nix-command flakes" <sub-commands>
    ```

- Prepare your Projecte Manager configuration (`.config/project/default.nix`).

  Unlike the channel-based setup, `.config/project/default.nix` will be evaluated when
  the flake is built, so it must be present before bootstrap of Project
  Manager from the flake. See [Configuration Example](#sec-usage-configuration) for
  introduction about writing a Project Manager configuration.
