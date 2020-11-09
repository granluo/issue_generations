#!/bin/sh

set -ex

python test.py
echo "::error :: Error message"
echo "Hello World"

echo "Hello $1"


