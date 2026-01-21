#!/bin/sh
# ABOUTME: Wrapper for bd (beads) that runs in sandbox mode
# ABOUTME: Disables daemon and auto-sync to prevent network timeouts in container

exec /usr/local/bin/bd-real --sandbox "$@"
