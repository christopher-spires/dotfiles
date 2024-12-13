#!/bin/bash
latest_dir=~/latest
bash_completion_dir=~/.bash_completion.d

podman_completion_file=podman-completion.bash
gradle_completion_file=gradle-completion.bash
maven_completion_file=maven-completion.bash

function dodiff() {
  local file=$1
  local source=${latest_dir}
  local dest=${bash_completion_dir}
  if [ ${#@} = 3 ]; then
    source=$2
    dest=$3
  fi
  if [ ${#@} = 2 ]; then
    dest=$2
  fi
  local from=$source/$file
  local to=$dest/$file
  echo 
  if ! diff -q "$from" "$to"; then
    echo "diff: diff '$from' '$to'";
    echo "update: cp '$from' '$to'";
  fi
}

curl -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o $latest_dir/git-completion.bash
curl -s https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -o $latest_dir/.git-prompt.sh
curl -s https://raw.githubusercontent.com/juven/maven-bash-completion/master/bash_completion.bash -o $latest_dir/$maven_completion_file
curl -s https://raw.githubusercontent.com/Azure/azure-cli/dev/az.completion -o $latest_dir/az.completion.bash
curl -sLA gradle-completion https://edub.me/gradle-completion-bash -o $latest_dir/$gradle_completion_file
chezmoi completion bash > $latest_dir/chezmoi-completion.bash
podman completion -f "$(cygpath -m $latest_dir/$podman_completion_file)" bash

gawk -i inplace '
    {
        print
        if ($0 ~ /^\s*complete.*podman.exe$/) {
            gsub(/ podman.exe/, " docker")
            print
        }
    }
' "$latest_dir/$podman_completion_file"

gawk -i inplace '
    {
        print
        if ($0 ~ /^\s*complete.*gradle$/) {
            gsub(/ gradle/, " g")
            print
        }
    }
' "$latest_dir/$gradle_completion_file"

gawk -i inplace '
    {
        print
        if ($0 ~ /^\s*complete.*mvn$/) {
            gsub(/ mvn/, " m")
            print
        }
    }
' "$latest_dir/$maven_completion_file"

dodiff git-completion.bash
dodiff .git-prompt.sh ~
dodiff chezmoi-completion.bash
dodiff $maven_completion_file
dodiff $gradle_completion_file
dodiff $podman_completion_file

