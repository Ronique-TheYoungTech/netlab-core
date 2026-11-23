#!/usr/bin/env bash
# 6x6 ping matrix. Usage: sudo ./matrix.sh phaseA   (or phaseB)
# Writes a Markdown table to results/matrix-<label>.md, ready for the README.
set -uo pipefail
cd "$(dirname "$0")"

LAB=l4
VLANS=(10 20 30 40 50 60)
LABEL=${1:-run}

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./matrix.sh $LABEL"; exit 1; }
pid() { docker inspect -f '{{.State.Pid}}' "clab-$LAB-$1"; }

mkdir -p results
out=results/matrix-$LABEL.md
pass=0; fail=0

{
  printf '| src \\ dst |'
  for d in "${VLANS[@]}"; do printf ' pc%s |' "$d"; done; echo
  printf '|---|'; for _ in "${VLANS[@]}"; do printf ':-:|'; done; echo
  for s in "${VLANS[@]}"; do
    p=$(pid "pc$s")
    printf '| **pc%s** |' "$s"
    for d in "${VLANS[@]}"; do
      if [[ $s == "$d" ]]; then printf ' — |'; continue; fi
      if nsenter -t "$p" -n ping -c 2 -W 1 "10.0.$d.10" >/dev/null 2>&1; then
        printf ' ✅ |'; pass=$((pass+1))
      else
        printf ' ❌ |'; fail=$((fail+1))
      fi
    done
    echo
  done
  echo
  echo "Result ($LABEL): $pass passed, $fail failed of 30 inter-host paths"
} | tee "$out"

# TTL proof: one routed hop means replies arrive with ttl=63
echo
echo "TTL check (expect ttl=63 = one routed hop):"
nsenter -t "$(pid pc10)" -n ping -c 1 10.0.60.10 | grep ttl | tee -a "$out"
