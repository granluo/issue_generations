#!/bin/sh

set -ex

echo "::error :: Error message"
echo "Hello World"

ruby app.rb

echo "Hola $1"


