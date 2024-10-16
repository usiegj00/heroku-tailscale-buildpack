#!/usr/bin/env bash

set -e

function log() {
  echo "-----> $*"
}

function indent() {
  sed -e 's/^/       /'
}

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  log "Skipping Tailscale"

else
  log "Starting Tailscale"

  if [ -z "$TAILSCALE_HOSTNAME" ]; then
    if [ -z "$HEROKU_APP_NAME" ]; then
      tailscale_hostname=$(hostname)
    else
      # Only use the first 8 characters of the commit sha.
      # Swap the . and _ in the dyno with a - since tailscale doesn't
      # allow for periods.
      DYNO=${DYNO//./-}
      DYNO=${DYNO//_/-}
      tailscale_hostname=${HEROKU_SLUG_COMMIT:0:8}"-$DYNO-$HEROKU_APP_NAME"
    fi
  else
    tailscale_hostname="$TAILSCALE_HOSTNAME"
  fi
  log "Using Tailscale hostname=$tailscale_hostname"

  log "Actually disown the tailscaled process so that it does not occupy the same session id and hang the shell (in the new exec.d execution environment)."
  tailscaled -cleanup > /dev/null 2>&1
  (tailscaled -verbose ${TAILSCALED_VERBOSE:--1} --tun=userspace-networking --socks5-server=localhost:1055 --socket=/tmp/tailscaled.sock > /dev/null 2>&1 &) 
  #nohup tailscaled -verbose ${TAILSCALED_VERBOSE:-0} --tun=userspace-networking --socks5-server=localhost:1055 --socket=/tmp/tailscaled.sock > /dev/null 2>&1 &
  until tailscale --socket=/tmp/tailscaled.sock \
    up \
    --authkey=${TAILSCALE_AUTH_KEY} \
    --hostname="$tailscale_hostname" \
    --accept-dns=${TAILSCALE_ACCEPT_DNS:-true} \
    --accept-routes=${TAILSCALE_ACCEPT_ROUTES:-true} \
    --advertise-exit-node=${TAILSCALE_ADVERTISE_EXIT_NODE:-false} \
    --shields-up=${TAILSCALE_SHIELDS_UP:-false}
  do
    log "Waiting for 5s for Tailscale to start"
    sleep 5
  done

  export ALL_PROXY=socks5://localhost:1055/
  log "Tailscale started"
fi

# Check if any arguments are provided
if [ "$#" -gt 0 ]; then
  # Execute the arguments as a command
  log "Running command."
  exec "$@"
else
  log "No command provided. Continuing..."
fi

