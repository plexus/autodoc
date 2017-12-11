# autodoc

Automate the publishing of generated docs.

Imagine the following scenario: you have files in a git repo, from which you generate HTML, which you want to make available on-line.

For example: you have source code from which you generate API docs, or you have markdown files that you run through a static site generator.

If you're using Github then getting these resulting files on-line is as easy as pushing to the `gh-pages` branch. This isn't hard, but you have to first generate the HTML, put it aside, switch branches, commit the change, push it to Github, and switch back. There are many little things that can go wrong in that process. It's also few minutes of your life that you just wasted doing a tedious, mechanical job, every time again.

Enter `autodoc`, a single shell script that automates this process as best as it can.

## Installation

The recommended, "evergreen" way of using `autodoc` is to create a small shell script in your repository, you can call it `generate_docs`, that looks like this:

``` shell
#!/bin/bash

# Command that generates the HTML.
export AUTODOC_CMD="lein codox"

# The directory where the result of $AUTODOC_CMD, the generated HTML, ends up. This
# is what gets committed to $AUTODOC_BRANCH.
# export AUTOAUTODOC_DIR="gh-pages"

# The git remote to fetch and push to. 
# export AUTODOC_REMOTE="origin"

# Branch name to commit and push to
# export AUTODOC_BRANCH="gh-pages"

\curl -sSL https://raw.githubusercontent.com/plexus/autodoc/master/autodoc.sh | bash
```

At a minimum you must set `AUTODOC_CMD`, this is the command that gets called to generate the HTML files.

If you're not comfortable running a shell script straight off the internets, you
can also just copy `autodoc.sh` to your project, and change the variables at the
top of the script.

## Usage instructions

Call `./generate_docs` at any time, and the HTML will immediately be updated and made available on-line. This is safe to do no matter the state of your repository. More on why that is below.

You can have local changes, untracked files, etc. The script does not actually switch branches, and does not change the current "working tree" beyond running `$AUTODOC_CMD`. `autodoc` does use the "git index" (also known as the "staging area"), so this needs to be clean. If you did a `git add` before then the script will complain and refuse to continue until you `commit` or `reset`.

## How it works

The procedure that `autodoc` follows has been tweaked over time to be as reliable and fool proof as possible. Here is roughly what it does, in order.

- Check if the git index is clean, otherwise exit
- Check if `$AUTODOC_CMD` is set, otherwise exit
- Do a `git fetch`, to know what the target branch looks like on the remote (e.g. `origin/gh-pages`)
- Clear out `$AUTOAUTODOC_DIR`. It deletes it if already there, and then creates it anew, to make sure you don't commit stale files.
- Run `$AUTODOC_CMD`
- Create a git "tree object" of the contents of `$AUTOAUTODOC_DIR`
- Generate a commit message which includes the source branch and commit hash, as well as an overview of any local changes
- Create a git "commit object" with this tree and message, and with as parent commit the latest commit on the target branch on the target remote
- Push this commit to `AUTODOC_REMOTE/AUTODOC_BRANCH` (e.g. `origin/gh-pages`)
- Display the commit with diff stats so you get some feedback on what happened

## Improving autodoc

This script has already seen a few iterations of polish, but it can without a doubt be further improved. Its needs to be reliable and safe, either doing its job, or bailing out and telling the user what the problem is.

If you can make it more reliable and safe then it currently is, then we'd love to get a pull request.

## Credits

Initially written by [Arne Brasseur](https://twitter.com/plexus), improved with the help of [Martin Klepsch](http://twitter.com/jackrusher/) and [Jack Rusher](http://twitter.com/martinklepsch/)

## License

Copyright &copy; Arne Brasseur and contributors

Available under the Mozilla Public License 2.0. See `LICENSE`.
