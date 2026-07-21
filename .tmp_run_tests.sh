#!/usr/bin/env bash
set -u
repo=$(printf '%s\n' /mnt/c/Users/HP*/Documents/GitHub/CBorrowing | head -n 1)
compiler=$(printf '%s\n' /mnt/c/Users/HP*/Documents/GitHub/nimony/bin/nimony | head -n 1)
cd "$repo" || exit 1
pass=0
fail=0
timeout_count=0
for f in tests/*.nim; do
  base=${f##*/}
  out=$(timeout 120s "$compiler" m "$f" 2>&1)
  status=$?
  if [ $status -eq 0 ]; then
    echo "PASS $base"
    pass=$((pass+1))
  elif [ $status -eq 124 ]; then
    echo "TIMEOUT $base"
    timeout_count=$((timeout_count+1))
  else
    echo "FAIL $base"
    echo "$out" | sed -n '1,2p'
    fail=$((fail+1))
  fi
done
echo "SUMMARY pass=$pass fail=$fail timeout=$timeout_count"
