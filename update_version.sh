#!/bin/bash

cp autodoc.sh /tmp
sed "s/VERSION=.*/$(printf "VERSION=%04d" `git rev-list --count HEAD`)/" /tmp/autodoc.sh > autodoc.sh
