#!/bin/bash

ACTION=$1

check_requirements() {
    MISSING=()
    command -v curl > /dev/null 2>&1 || MISSING+=("curl")
    command -v vim > /dev/null 2>&1 || MISSING+=("vim")
    command -v git > /dev/null 2>&1 || MISSING+=("git")

    if [ ${#MISSING[@]} -ne 0 ]; then
        echo "The following required programs are missing: ${MISSING[*]}"
        read -p "Would you like to install them? [y/N]: " INSTALL_MISSING
        if [[ "$INSTALL_MISSING" =~ ^[Yy]$ ]]; then
            sudo pacman -S ${MISSING[*]}
        else
            echo "Cannot proceed without required programs. Exiting."
            exit 1
        fi
    fi
}

backup_vimrc() {
    [ -f "$HOME/.vimrc" ] && cp "$HOME/.vimrc" "$HOME/.vimrc.backup.$(date +%F_%T)" && echo "Backup created: ~/.vimrc.backup.$(date +%F_%T)"
}

if [ "$ACTION" == "install" ]; then
    check_requirements
    backup_vimrc
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    {
        echo ""
        echo "set t_Co=256"
        echo "syntax on"
        echo "call plug#begin('~/.vim/plugged')"
        echo "Plug 'vim-airline/vim-airline'"
        echo "Plug 'vim-airline/vim-airline-themes'"
        echo "call plug#end()"
        echo "colorscheme desert"
        echo "let g:airline#extensions#tabline#enabled = 1"
        echo "let g:airline_theme='deus'"
    } >> "$HOME/.vimrc"
    echo "Configuration applied. Restart Vim and run :PlugInstall to install plugins."
    exit 0
fi

if [ "$ACTION" == "uninstall" ]; then
    check_requirements
    if ls ~/.vimrc.backup.* 1> /dev/null 2>&1; then
        LATEST_BACKUP=$(ls -t ~/.vimrc.backup.* | head -n 1)
        cp "$LATEST_BACKUP" "$HOME/.vimrc"
        echo "Restored backup from $LATEST_BACKUP"
    else
        echo "No backup found to restore. Cleaning .vimrc manually."
        sed -i '/set t_Co=256/d' "$HOME/.vimrc"
        sed -i '/syntax on/d' "$HOME/.vimrc"
        sed -i '/call plug#begin/d' "$HOME/.vimrc"
        sed -i "/Plug 'vim-airline\/vim-airline'/d" "$HOME/.vimrc"
        sed -i "/Plug 'vim-airline\/vim-airline-themes'/d" "$HOME/.vimrc"
        sed -i '/call plug#end/d' "$HOME/.vimrc"
        sed -i '/colorscheme desert/d' "$HOME/.vimrc"
        sed -i '/let g:airline#extensions#tabline#enabled = 1/d' "$HOME/.vimrc"
        sed -i "/let g:airline_theme='deus'/d" "$HOME/.vimrc"
    fi
    rm -rf ~/.vim/plugged
    rm -f ~/.vim/autoload/plug.vim
    echo "Uninstallation complete."
    exit 0
fi

echo "Usage: $0 {install|uninstall}"

