# Getting started {#sec-contrib-getting-started}

<!-- vale Vale.Spelling = NO -->

If you haven’t forked Project Manager yet, then you need to do that
first. Have a look at GitHub's [Fork a
repo](https://help.github.com/articles/fork-a-repo/) for instructions on
how to do this.

<!-- vale Vale.Spelling = YES -->

Once you have a fork of Project Manager you should create a branch starting
at the most recent `master` branch. Give your branch a reasonably
descriptive name. Commit your changes to this branch and when you are
happy with the result and it fulfills [Guidelines](#sec-guidelines) then
push the branch to GitHub and [create a pull
request](https://help.github.com/articles/creating-a-pull-request/).

Assuming your clone is at `$HOME/devel/project-manager` then you can make
the `project-manager` command use it by either

1.  overriding the default path by using the `-I` command line option:

    ```shell
    $ project-manager -I project-manager=$HOME/devel/project-manager
    ```

    or, if using [flakes](#sec-flakes-standalone):

    ```shell
    $ project-manager --override-input project-manager ~/devel/project-manager
    ```

    or

2.  changing the default path by ensuring your configuration includes

    ```nix
    programs.project-manager.enable = true;
    programs.project-manager.path = "$HOME/devel/project-manager";
    ```

    and running `project-manager switch` to activate the change.
    Afterward, `project-manager build` and `project-manager switch` will use
    your cloned repository.

The first option is good if you only temporarily want to use your clone.
