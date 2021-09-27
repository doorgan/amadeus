#!/usr/bin/env bash
# exit on error
set -o errexit

vsn=$(cat mix.exs | grep version | sed -e 's/.*version: "\(.*\)",/\1/')

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Build the release and overwrite the existing release directory
MIX_ENV=prod mix release --overwrite --path ./artifacts
