#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
exotic1="${EXOTIC1_ROOT:?EXOTIC1_ROOT is required}"
shen_go="${SHEN_GO:-$root/../shen-go/.bin/shen-go}"
shen_lua="${SHEN_LUA:-$root/../shen-lua/bin/shen}"

test -x "$shen_go"
test -x "$shen_lua"
test -f "$exotic1/kernel/load.shen"

program="$(mktemp)"
cat >"$program" <<EOF
(load "$exotic1/kernel/load.shen")
(load "$root/shen/ac-bytes.shen")
(load "$root/shen/ac-backend.shen")
(load "$root/shen/ac-flow.shen")

(define exotic-acadia-check
  -> (and (= 8800 (quality-score 60 -50 50))
          (and (= "000000000000000100000008000000000000000100000008000000000000000a00000003414855000000084f76657268656174"
                  (ac.hex (ac.find-fault 1 10 "AHU" "Overheat")))
               (= [flow [1] []]
                  (ac.flow 20
                    [[candidate 1 10 20 200 30 "Overheat" 2 "AHU" 1]]
                    [])))))

(if (exotic-acadia-check)
    (output "EXOTIC-ACADIA PASS~%")
    (output "EXOTIC-ACADIA FAIL~%"))
EOF

go_out="$(cd "$exotic1" && "$shen_go" script "$program")"
lua_out="$(cd "$exotic1" && SHEN_FASL=off "$shen_lua" --hush-load "$program")"

printf '%s\n' "$go_out" | grep -q '^EXOTIC-ACADIA PASS$'
printf '%s\n' "$lua_out" | grep -q '^EXOTIC-ACADIA PASS$'
echo "EXOTIC-ACADIA PASS shen-go shen-lua"
