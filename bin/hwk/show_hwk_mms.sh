#!/bin/bash

set -e

journalctl -kb0 --grep 'mm@' | cut -f 2 -d '@' | cut -f 1 -d ',' | sort -u
