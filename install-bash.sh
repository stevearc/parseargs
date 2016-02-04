#!/bin/bash
# Utility for downloading & making a bash version. Useful for testing.
curl -o bash-${1}.tar.gz ftp://ftp.gnu.org/gnu/bash/bash-${1}.tar.gz
tar -zxf bash-${1}.tar.gz
pushd bash-${1} && ./configure && make && popd
