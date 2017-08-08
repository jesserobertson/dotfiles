#!/usr/bin/env bash
# file:   setup_debian.sh
# author: Jess Robertson
# date:   August 2015
#
# Sets up a Debian VM from scratch. There are many init scripts, but this one is mine.

## INSTALL SYSTEM LIBS
# Somewhere to stick local packages
export LOCAL="${HOME}/.local"

# Install packages using apt-get
sudo apt-get update
sudo apt-get install git tig vim screen bash-completion bzip2 ruby wget curl silversearcher-ag

## INSTALL VIM AND BASH CONFIG
# link configs
ln -s vimrc ~/.vimrc 
ln -s bashrc ~/.bashrc
ln -s logout ~/.logout

# Add pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Install ctrlp.vim etc
cd ~/.vim 
rm -rf bundle
git clone https://github.com/ctrlpvim/ctrlp.vim.git bundle/ctrlp.vim
git clone https://github.com/sjl/gundo.vim.git bundle/gundo
git clone https://github.com/rking/ag.vim bundle/ag

## INSTALL DOCKER
wget -qO- https://get.docker.com/ | sh

# Add current user to docker group for non-root access
sudo usermod -aG docker ubuntu

## INSTALL CONDA
# Set up where we're going to stick it
export CONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh"
export CONDA_HOME="${LOCAL}/conda"

# Set up paths
# Note that conda spews if CONDA_HOME already exists
mkdir -p ${LOCAL}/bin

# Actually do install
rm -rf ${CONDA_HOME}
wget --quiet ${CONDA_URL} -O miniconda.sh
/bin/bash miniconda.sh -b -p ${CONDA_HOME}
rm miniconda.sh
${CONDA_HOME}/bin/conda install --yes conda==3.10.1
export PATH=${CONDA_HOME}/bin:$PATH

# Configure conda to use Jess' binstar channel
conda config --set always_yes yes --set changeps1 no
conda config --add channels jesserobertson
conda update -q conda
conda info