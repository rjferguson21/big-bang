#!/bin/bash
function bad_function {
   set +e
   while true; do
      if true; then
         echo "bad_function exiting 1"
         exit 1
      fi
   done
   set -e
}
