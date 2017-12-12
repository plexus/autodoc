#!/bin/bash

# this is used as a pre-commit hook, the version is just the number of commits on master

cp autodoc.sh /tmp
sed "s/VERSION=.*/$(printf "VERSION=%04d" `git rev-list --count HEAD`)/" /tmp/autodoc.sh > autodoc.sh
