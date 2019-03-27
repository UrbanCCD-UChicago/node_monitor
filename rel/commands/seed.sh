#!/bin/sh

release_ctl eval --mfa "NodeMonitor.ReleaseTasks.seed/1" --argv -- "$@"
