#!/bin/bash

set -e

for f in examples/*.porth; do
    echo "Running: $f"
    if ! ./run.sh com "$f" -r; then
        echo "Error running $f"
        exit 1
    fi
done

echo "All tests passed"
