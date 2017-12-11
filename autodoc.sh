#!/bin/bash

# Keep a separate branch of generated API docs.
#
# This script generates API documentation, commits it to a separate branch, and
# pushes it upstream. It does this without actually checking out the branch,
# using a separate working tree directory, so without any disruption to your
# current working tree. You can have local file modifications, but the git index
# (staging area) must be clean.

############################################################
# These variables can all be overridden from the command line,
# e.g. TARGET_REMOTE=plexus ./generate_docs

# The git remote to fetch and push to. Also used to find the parent commit.
TARGET_REMOTE=${TARGET_REMOTE:-"origin"}

# Branch name to commit and push to
TARGET_BRANCH=${TARGET_BRANCH:-"gh-pages"}

# Command that generates the API docs
#DOC_CMD=${DOC_CMD:-"lein with-profile +codox codox"}
#DOC_CMD=${DOC_CMD:-"boot codox -s src -n my-project -o gh-pages target"}

# Working tree directory. The output of $DOC_CMD must end up in this directory.
DOC_DIR=${DOC_DIR:-"gh-pages"}

############################################################

if ! git diff-index --quiet --cached HEAD ; then
    echo "Git index isn't clean. Make sure you have no staged changes. (try 'git reset .')"
    exit 1
fi

if [[ -z "$DOC_CMD" ]]; then
    echo "Please specify a DOC_CMD, e.g. lein codox"
    exit 1
fi

MESSAGE="Updating docs based on $(git rev-parse --abbrev-ref HEAD) $(git rev-parse HEAD)"

if [[ ! -z "$(git status --porcelain)" ]]; then
  MESSAGE="$MESSAGE

    Status:
$(git status --short)

    Diff:
$(git diff)"
fi

# Fetch the remote, we don't care about local branches, only about what's
# currently on the remote
git fetch $TARGET_REMOTE

# Start from a clean slate, we only commit the new output of DOC_CMD, nothing else.
rm -rf $DOC_DIR
mkdir -p $DOC_DIR

echo "Generating docs"
$DOC_CMD

if [ $(find $DOC_DIR -maxdepth 0 -type d -empty 2>/dev/null) ]; then
    echo "The command '$DOC_CMD' created no output in `$DOC_DIR`, giving up"
    exit 1
fi

# The full output of DOC_CMD is added to the git index, staged to become a new
# file tree+commit
echo "Adding file to git index"
git --work-tree=$DOC_DIR add -A

# Create a git tree object with the exact contents of $DOC_DIR (the output of
# the DOC_CMD), this will be file tree of the new commit that's being created.
TREE=`git write-tree`
echo "Created git tree $TREE"

# Create the new commit, either with the previous remote HEAD as parent, or as a
# new orphan commit
if git show-ref --quiet --verify "refs/remotes/${TARGET_REMOTE}/${TARGET_BRANCH}" ; then
    PARENT=`git rev-parse ${TARGET_REMOTE}/${TARGET_BRANCH}`
    echo "Creating commit with parent refs/remotes/${TARGET_REMOTE}/${TARGET_BRANCH} ${PARENT}"
    COMMIT=$(git commit-tree -p $PARENT $TREE -m "$MESSAGE")
else
    echo "Creating first commit of the branch"
    COMMIT=$(git commit-tree $TREE -m "$MESSAGE")
fi

echo "Pushing $COMMIT to $TARGET_BRANCH"

# Rest the index, commit-tree doesn't do that by itself. If we don't do this
# `git status` or `git diff` will look *very* weird.
git reset .

# Push the newly created commit to remote
if [[ ! -z "$PARENT" ]] && [[ $(git rev-parse ${COMMIT}^{tree}) == $(git rev-parse refs/remotes/$TARGET_REMOTE/$TARGET_BRANCH^{tree} ) ]] ; then
    echo "WARNING: No changes in documentation output from previous commit. Not pushing to ${TARGET_BRANCH}"
else
    git push $TARGET_REMOTE $COMMIT:refs/heads/$TARGET_BRANCH
    # Make sure our local remotes are up to date.
    git fetch
    # Show what happened, you should see a little stat diff here of the changes
    echo
    git log -1 --stat $TARGET_REMOTE/$TARGET_BRANCH
fi
