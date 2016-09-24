#!/bin/sh

curl -LR#O "http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz"
curl -LR#O "http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz"
gunzip -k t10k-images-idx3-ubyte.gz
gunzip -k t10k-labels-idx1-ubyte.gz
