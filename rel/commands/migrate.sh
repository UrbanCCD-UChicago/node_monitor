#!/bin/sh

release_ctl eval --mfa "NodeMonitor.ReleaseTasks.migrate/1" --argv -- "$@"
