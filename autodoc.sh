#!/bin/bash

# Keep a separate branch of generated API docs.
#
# This script generates API documentation, commits it to a separate branch, and
# pushes it upstream. It does this without actually checking out the branch,
# using a separate working tree directory, so without any disruption to your
# current working tree. You can have local file modifications, and/or files in
# the staging area, but be warned it will be difficult to track the origin
# of your documentation if the tree isn't committed.

############################################################
# These variables can all be overridden from the command line,
# e.g. AUTODOC_REMOTE=plexus ./generate_docs

# The git remote to fetch and push to. Also used to find the parent commit.
AUTODOC_REMOTE=${AUTODOC_REMOTE:-"origin"}

# Branch name to commit and push to
AUTODOC_BRANCH=${AUTODOC_BRANCH:-"gh-pages"}

# Command that generates the API docs
#AUTODOC_CMD=${AUTODOC_CMD:-"lein with-profile +codox codox"}
#AUTODOC_CMD=${AUTODOC_CMD:-"boot codox -s src -n my-project -o gh-pages target"}

# Working tree directory. The output of $AUTODOC_CMD must end up in this directory.
AUTODOC_DIR=${AUTODOC_DIR:-"gh-pages"}

# Working tree subdirectory. This is for situations where the caller
# wishes to preserve multiple versions of the documentation. When
# non-empty then the output of $AUTODOC_CMD must end up in
# $AUTODOC_DIR/$AUTODOC_SUBDIR
AUTODOC_SUBDIR=${AUTODOC_SUBDIR:-""}

############################################################

function echo_info() {
   echo -en "[\033[0;32mautodoc\033[0m] "
   echo $*
}

function echo_error() {
   echo -en "[\033[0;31mautodoc\033[0m] "
   echo $*
}

if [[ -z "$AUTODOC_CMD" ]]; then
    echo_error "Please specify a AUTODOC_CMD, e.g. lein codox"
    exit 1
fi

VERSION=0022

echo "//======================================\\\\"
echo "||          AUTODOC v${VERSION}               ||"
echo "\\\\======================================//"

MESSAGE="Updating docs ($AUTODOC_DIR/$AUTODOC_SUBDIR) from commit $(git rev-parse --short HEAD) on branch $(git rev-parse --abbrev-ref HEAD)

Ran: $AUTODOC_CMD
"

if [[ ! -z "$(git status --porcelain)" ]]; then
  MESSAGE="$MESSAGE
Repo not clean.

    Status:
$(git status --short)

    Diff:
$(git diff)"
fi

# Fetch the remote. We don't care about local branches, only about
# what's currently on the remote. Using the explicit "+refs/heads/..."
# syntax like this looks overly complicated but is necessary in CI
# environments like Travis CI where only the specific branch of the
# repo is cloned.
git fetch $AUTODOC_REMOTE "+refs/heads/${AUTODOC_BRANCH}:refs/remotes/${AUTODOC_REMOTE}/${AUTODOC_BRANCH}"

# Start from a clean slate, we only commit the new output of AUTODOC_CMD, nothing else.
rm -rf $AUTODOC_DIR
mkdir -p $AUTODOC_DIR

echo_info "Generating docs"
echo $AUTODOC_CMD | bash

AUTODOC_RESULT=$?

if [[ ! $AUTODOC_RESULT -eq 0 ]]; then
    echo_error "The command '${AUTODOC_CMD}' returned a non-zero exit status (${AUTODOC_RESULT}), giving up."
    exit $AUTODOC_RESULT
fi

# Confirm there is new output in the specified dir
if [[ -z "$AUTODOC_SUBDIR" ]]; then
    if [[ $(find $AUTODOC_DIR -maxdepth 0 -type d -empty 2>/dev/null) ]]; then
        echo_error "The command '$AUTODOC_CMD' created no output in '$AUTODOC_DIR', giving up"
        exit 1
    fi
else
    if [[ $(find $AUTODOC_DIR/$AUTODOC_SUBDIR -maxdepth 0 -type d -empty 2>/dev/null) ]]; then
        echo_error "The command '$AUTODOC_CMD' created no output in '$AUTODOC_DIR/$AUTODOC_SUBDIR', giving up"
        exit 1
    fi
fi

# Create a temp dir
AUTODOC_TMP=$(mktemp -d /tmp/autodoc.XXXXXXXX)
AUTODOC_RESULT=$?
if [[ ! $AUTODOC_RESULT -eq 0 ]]; then
    echo_error "mktemp returned a non-zero exit status (${AUTODOC_RESULT}), giving up."
    exit $AUTODOC_RESULT
fi

# Use a temp index to construct the tree to commit
export GIT_INDEX_FILE=$AUTODOC_TMP/index

# Determine the parent commit (if any) on AUTODOC_BRANCH
if git show-ref --quiet --verify "refs/remotes/${AUTODOC_REMOTE}/${AUTODOC_BRANCH}" ; then
    PARENT=`git rev-parse ${AUTODOC_REMOTE}/${AUTODOC_BRANCH}`
fi

# Prepare index
if [[ ! -z "$AUTODOC_SUBDIR" && ! -z "$PARENT" ]]; then
    # If there is a parent commit on AUTODOC_BRANCH, and we're
    # preserving other subdirs, then we need to read-tree the previous
    # state of AUTODOC_DIR
    echo_info "Reading tree from parent commit"
    PARENT_TREE=`git rev-parse $PARENT^{tree}`
    git read-tree $PARENT_TREE
    # We remove any remnant of the last subdir from the index
    git rm --cached -r $AUTODOC_SUBDIR
    # Add in the current generated docs
    echo_info "Merging new docs into git index"
    git --work-tree=$AUTODOC_DIR add --no-all .
else
    # If we're not preserving subdirs or we don't have a parent then
    # the full output of AUTODOC_CMD is added to the git index, staged
    # to become a new file tree+commit
    echo_info "Adding docs to git index"
    git --work-tree=$AUTODOC_DIR add -A
fi

# Write the git tree with the exact contents of index.
TREE=`git write-tree`
echo_info "Created git tree $TREE"

# Create the new commit, either with the previous remote HEAD as parent, or as a
# new orphan commit
if [[ ! -z "$PARENT" ]]; then
    echo_info "Creating commit with parent refs/remotes/${AUTODOC_REMOTE}/${AUTODOC_BRANCH} ${PARENT}"
    COMMIT=$(git commit-tree -p $PARENT $TREE -m "$MESSAGE")
else
    echo_info "Creating first commit of the branch"
    COMMIT=$(git commit-tree $TREE -m "$MESSAGE")
fi

# Restore the original git index and clean up the temp dir
unset GIT_INDEX_FILE
rm -rf $AUTODOC_TMP

echo_info "Pushing $COMMIT to $AUTODOC_BRANCH"

# Push the newly created commit to remote
if [[ ! -z "$PARENT" ]] && [[ $(git rev-parse ${COMMIT}^{tree}) == $(git rev-parse refs/remotes/$AUTODOC_REMOTE/$AUTODOC_BRANCH^{tree} ) ]] ; then
    echo_error "WARNING: No changes in documentation output from previous commit. Not pushing to ${AUTODOC_BRANCH}"
else
    git push $AUTODOC_REMOTE $COMMIT:refs/heads/$AUTODOC_BRANCH
    # Make sure our local remotes are up to date.
    git fetch
    # Show what happened, you should see a little stat diff here of the changes
    echo
    git log -1 --stat $AUTODOC_REMOTE/$AUTODOC_BRANCH
fi
