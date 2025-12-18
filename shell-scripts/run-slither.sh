#!/bin/bash

docker build -t my-eth-toolbox . 
docker run --rm -it my-eth-toolbox slither "$@" --filter-paths lib 