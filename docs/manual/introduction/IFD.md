# avoiding `import-from-derivation` (IFD) {#sec-project-manager-ifd}

If you are a Nix user in certain ecosystems (for example, Haskell), you may already be well-acquainted with IFD. It can be difficult to avoid.

One of the tradeoffs is that to avoid IFD, you need to run a separate process (for example, `cabal2nix`) and commit its outputs before your project will work. And it can be easy for those to get out of date as things evolve, leading to confusing failures.

IFD runs these processes as part of Nix evaluation, meaning they don’t get out of date or need to be committed, but it makes evaluation slower and unpredictable, often with more confusing failures than the build phase.

Project Manager mitigates this issue, by providing modules for common Nix-producing programs, unifying generation & staging under `project-manager switch`. And with Project Manager’s checks, `nix flake check` will tell you when those files have gotten out of date.
