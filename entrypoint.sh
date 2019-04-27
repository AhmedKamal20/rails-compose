#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f tmp/pids/server.pid

# Remove a potentially pre-existing server.pid for Rails.
bundle install

# Do the pending migrations.
if psql -lqt | cut -d \| -f 1 | grep -qw app_development; then
  rails db:migrate
else
  rails db:create
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
