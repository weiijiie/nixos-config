alias terra="terraform"
alias tf="terraform"
alias python="python3"
alias cat="bat --paging=\"never\" --style=\"plain\""
alias upper="tr '[:lower:]' '[:upper:]'"
alias lower="tr '[:upper:]' '[:lower:]'"
alias drop_cache="sudo sh -c \"echo 3 >'/proc/sys/vm/drop_caches' && swapoff -a && swapon -a && printf '\n%s\n' 'Ram-cache and Swap Cleared'\""
alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

# kubectl aliases
alias kctl="kubectl"
alias kdash='kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | awk "/^deployment-controller-token-/{print \$1}") | awk "\$1==\"token:\"{print \$2}"'
alias kdelfns="kubectl-force-delete-namespace" 

# git aliases
alias "g-"="git checkout -"
alias gbas="git branch --sort=-committerdate --format='%(HEAD) %(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias "gco?"="git-select-checkout"
alias gdiffs="git-stepwise-diff"

