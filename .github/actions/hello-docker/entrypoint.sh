#!/bin/sh

set -ex

# echo "::error :: Error message"
echo "Hello World"

ls -a
echo "Hola $1"
echo "Hola $2"

printenv

ruby /myapp/app.rb



