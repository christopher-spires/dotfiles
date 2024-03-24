#!/bin/bash
latest_dir=~/latest
curl -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $latest_dir/git-completion.bash
curl -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o $latest_dir/git-prompt.sh
curl -s https://raw.githubusercontent.com/juven/maven-bash-completion/master/bash_completion.bash -o maven-completion.bash
chezmoi completion bash > $latest_dir/chezmoi-completion.bash

diff -q $latest_dir/git-completion.bash ~/.bash_completion.d/git-completion.bash
diff -q $latest_dir/git-prompt.sh ~/.git-prompt.sh
diff -q $latest_dir/chezmoi-completion.bash ~/.bash_completion.d/chezmoi-completion.bash
diff -q $latest_dir/maven-completion.bash ~/.bash_completion.d/maven-completion.bash
