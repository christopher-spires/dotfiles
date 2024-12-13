#!/bin/bash
# review.sh:
# requirements: bat intellij/vscode for opening in editor.
# created to go through the file using command line for git commits
# see the diffs file by file
# through iterations it went through various syntax highlighters. Currently using bat.
# Starts using a list of modified files
# ideas?
# fix index (off by one in display)
# diff options (in another menu?)
# other options? (in another menu?)
# F = change file list? o m branch? (in another menu?)

[[ -n "$DEBUG" ]] && set -x

declare -a files
file=
(( file_idx=0 ))
(( file_count=0 ))
(( style_idx=0 ))
(( hl_out_idx=0 ))
styles=( github bclear bright darkbone edit-bbedit freya matrix rootwater sourceforge the whitengrey xoria256 zenburn )
(( style_count=${#styles[@]} ))
hl_out=( truecolor xterm256 ansi )
(( hl_out_count=${#hl_out[@]} ))
ANSI_DEFAULT="\e[39m"
LIGHT_RED="\e[91m"
LIGHT_GREEN="\e[92m"
LIGHT_YELLOW="\e[93m"
_LIGHT_BLUE="\e[94m"
_LIGHT_MAGENTA="\e[95m"
_LIGHT_CYAN="\e[96m"
_LIGHT_WHITE="\e[97m"
_LIGHT_WHITE="\e[98m"
_LIGHT_COLOR="\e[99m"

WARN_COLOR="${LIGHT_YELLOW}"

ERROR_COLOR="${LIGHT_RED}"

LIST_COLOR="${LIGHT_GREEN}"

intellij=/proc/cygdrive/c/Users/$USER/AppData/Local/JetBrains/Toolbox/scripts/idea.cmd
vscode=code

debug() {
 [[ -n "$DEBUG" ]] && echo "$*" 1>&2
}

warn() {
  echo -e "${WARN_COLOR}$*${ANSI_DEFAULT}"
}

error() {
  echo -e "${ERROR_COLOR}$*${ANSI_DEFAULT}"
}

list() {
  echo -e "${LIST_COLOR}$*${ANSI_DEFAULT}"
}


next_file() {
  debug next_file;
  [[ $file_idx -ge $file_count-1 ]] && error last file && return
  (( file_idx++ ))
  debug file_idx="$file_idx";
  set_file
}

next_style() {
  debug next_style;
  [[ $style_idx -ge $style_count-1 ]] && error last style && return
  (( style_idx++ ))
  debug style_idx="$style_idx";
  set_style
}

next_output() {
  debug next_output;
  [[ $hl_out_idx -ge $hl_out_count-1 ]] && error last output && return
  (( hl_out_idx++ ))
  debug hl_out_idx="$hl_out_idx"
  set_output
}

previous_file() {
  debug previous_file;
  [[ $file_idx -le 0 ]] && error first file && return
  (( file_idx-- ))
  debug file_idx="$file_idx"
  set_file
}

previous_style() {
  debug previous_style;
  [[ $style_idx -le 0 ]] && error first style && return
  (( style_idx-- ))
  debug style_idx="$style_idx"
  set_style
}

previous_output() {
  debug previous_style;
  [[ $hl_out_idx -le 0 ]] && error first output && return
  (( hl_out_idx-- ))
  debug hl_out_idx="$hl_out_idx"
  set_output
}

set_file() {
  file="${files[$file_idx]}"
  debug file="$file"
}

set_style() {
  style="${styles[$style_idx]}"
  # debug style="$style"
  warn "setting style to $style"
}

set_output() {
   output="${hl_out[$hl_out_idx]}"
   warn "setting output to $output"
}

glsm() {
  git ls-files -m
}

glso() {
  git ls-files -o --exclude-standard 
}

set_files() {
  file_idx=0
  file_count=${#files[@]}
  local last_file=$(( file_count > 0 ? file_count - 1 : 0 ))
  set_file
  echo "read $file_count files"
  debug "file : $file"
  debug "first: ${files[0]}"
  debug "last : ${files[$last_file]}"
}

set_modified_files() {
  echo reading modified files...
  # files=( $( glsm ) )
  mapfile -t files < <(glsm)
  set_files  
}

set_other_files() {
  echo reading other files...
  mapfile -t files < <(glso)
  
  set_files
}

git_add() {
  debug git_add
  echo "adding $file"
  git add "$file"
  next_file
}

git_diff() {
  debug git_diff
  git diff -b "$file"
}

git_Diff() {
  debug git_Diff
  git diff "$file"
}

style() {
  # style=paraiso-dark;
  #style=eclipse;
  # formatter=256;
  # pygmentize -f ${formatter} -O style=${style} $file
  # highlight -O "${output}" --canvas=100 --style="${style}" "$file"
  bat "$file"
}

git_reset() {
  debug git_reset
  git reset HEAD "$file" && next_file
}

git_checkout() {
  debug git_checkout
  confirm && git checkout -- "$file" && next_file
}

git_list() {
  debug git_list
  # echo "files=$files"
  printf '%s\n' "$( list "${files[@]}" )"
}

set_index() {
  echo not implemented
}

edit_file() {
  "$intellij" "$file" --line 1
}

edit_file_vscode() {
  "$vscode" "$file" --line 1
}

progress() {
  local file_idx_1=$(( file_count > 0 ? file_idx + 1 : 0 ))    
  echo -n "${file_idx_1}/${file_count}"
}

quit() {
  debug quit
}

confirm() {
  read -rp "confirm (yes?) " choice
  [[ "${choice,,}" == "yes" ]] && return 0
  echo aborting...
  return 1
}

menu() {
  debug opt="$opt"
  until [ "$opt" = "q" ];
  do
    prompt="(d|D)iff (s)tyle (N)ext-style (a)dd (r)eset (n)ext (p)revious (l)ist (i)ndex (e)dit (v)scode (M)odified (O)ther (C)heckout (q)uit :"
	# read -r -t 1 -n 10000 discard
	# while read -r -t 0; do read -n 256 -r -s; done
	# progress_prompt="$(progress)"
	# file_prompt="$(warn "$file")"
	echo "$(progress) $(warn "${file}")"
	echo -n "$prompt"
    read -r -n 1 -s opt
	echo    
	
	case ${opt} in
	  "C") git_checkout;;
	  "M") set_modified_files;;
	  "O") set_other_files;;
    "d") select_view;;
	  "D") git_Diff;;
	  "s") style;;
	  "o") next_output;;
	  "N") next_style;;
	  "P") previous_style;;
    "a") git_add;;
    "r") git_reset;;
    "n") next_file;;
	  "p") previous_file;;
    "l") git_list;;
	  "i") set_index;;
	  "e") edit_file;;
    "v") edit_file_vscode;;
    "q") quit; break;;
	  *) echo "invalid option: $opt"; read -r -t 1 -n 10000 _;;
	esac
  done
}

select_view() {
  if [[ $(is_version_controlled) ]]; then git_diff; else style; fi
}

is_version_controlled() {
  echo "$file=file"
  git ls-files --error-unmatch "$file" >& /dev/null
}

options() {
	case ${opt} in
	  "d") diff_options;;
	  "f") file_options;;
    "q") quit; return;;
	  *) echo "invalid option: $opt"; read -r -t 1 -n 10000 _;;
	esac
}

diff_options() {
	case ${opt} in
	  "i") ignore_blankspace;;
	  "b") blankspace_matters;;
      "q") quit; return;;
	  *) echo "invalid option: $opt"; read -r -t 1 -n 10000 _;;
	esac
}

set_modified_files
set_style
set_output

menu
debug exit script
