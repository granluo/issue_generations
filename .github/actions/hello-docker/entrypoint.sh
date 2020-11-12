#!/bin/sh

set -ex

echo "::error :: Error message"
echo "Hello World"

ruby myapp/app.rb

echo "Hola $1"


