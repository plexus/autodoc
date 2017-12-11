# autodoc

Automate the publishing of generated docs.

Imagine the following scenario: you have files in a git repo, from which you generate HTML, which you want to make available on-line.

For example: you have source code from which you generate API docs, or you have markdown files that you run through a static site generator.

If you're using Github then getting these resulting files on-line is as easy as pushing to the `gh-pages` branch. This isn't hard, but you have to first generate the HTML, put it aside, switch branches, commit the change, push it to Github, and switch back. There are many little things that can go wrong in that process. It's also few minutes of your life that you just wasted doing a tedious, mechanical job, every time again.

Enter `autodoc`, a single shell script that automates this process as best as it can.

## Installation

Copy the `autodoc` script 

