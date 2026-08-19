(load "load.shen")

(define check
  Label true -> (do (output (cn "PASS " (cn Label "~%"))) true)
  Label _ -> (do (output (cn "FAIL " (cn Label "~%"))) false))

(define all-true
  [] -> true
  [true | Xs] -> (all-true Xs)
  _ -> false)

(define run-tests
  -> (let AddApple (ac.hex (ac.add-food "apple"))
          Get (ac.hex (ac.get-foods))
          Find (ac.hex (ac.find-fault 1 10 "AHU" "Overheat"))
          Link (ac.hex (ac.link-rec 30 90))
          FindScenario (ac.hex (ac.find-scenario-rec 30))
          Wide (ac.hex (ac.enc-u64 4294967297))
          Max (ac.hex (ac.enc-u64 [u64 4294967295 4294967295]))
          EAcute (n->string 233)
          Unicode (ac.enc-string EAcute)
          Unit (ac.dec-unit [0 0 0 0])
          Negative (ac.dec-string [255 255 255 255])
          Base [[candidate 1 10 20 200 30 "Overheat" 2 "AHU" 1]]
          BlankFirst [[candidate 1 10 20 200 30 "Overheat" 2 "" 1]
                      [candidate 1 10 20 200 30 "Overheat" 2 "AHU" 2]]
          Ambiguous [[candidate 1 10 20 200 30 "Overheat" 2 "AHU" 1]
                     [candidate 1 10 20 200 30 "Overheat" 2 "FCU" 2]]
          \\ 1-item list: LE count 1, string "apple", LE 0
          OneList (ac.dec-strings
                    (append (ac.u32le 1)
                            (append (ac.enc-string "apple") (ac.u32le 0))))
          Empty (ac.dec-strings (ac.u32le 0))
          Round (ac.dec-string (ac.enc-string "bread"))
          Results
            [(check "add-food-apple"
                    (= AddApple "0000000000000006000000056170706c65"))
             (check "get-foods" (= Get "0000000000000007"))
             (check "find-fault"
                    (= Find
                       "000000000000000100000008000000000000000100000008000000000000000a00000003414855000000084f76657268656174"))
             (check "link-rec"
                    (= Link
                       "000000000000000500000008000000000000001e00000008000000000000005a"))
             (check "find-scenario-rec"
                    (= FindScenario "000000000000000300000008000000000000001e"))
             (check "uint64-wide" (= Wide "000000080000000100000001"))
             (check "uint64-max" (= Max "00000008ffffffffffffffff"))
             (check "utf8-encode" (= (ac.hex Unicode) "00000002c3a9"))
             (check "utf8-decode" (= (ac.dec-string Unicode) [ok EAcute]))
             (check "dec-unit" (= Unit [ok unit]))
             (check "dec-u64"
                    (= (ac.dec-u64 [0 0 0 8 0 0 0 1 0 0 0 1]) [ok 4294967297]))
             (check "dec-u64-list"
                    (= (ac.dec-u64s
                         [1 0 0 0 0 0 0 8 0 0 0 0 0 0 0 90 0 0 0 0])
                       [ok [90]]))
             (check "dec-negative" (= Negative [fail "string: negative length"]))
             (check "flow-base" (= (ac.flow 20 Base []) [flow [1] []]))
             (check "flow-psi-not-instance" (= (ac.flow 200 Base []) [flow [] []]))
             (check "flow-fleet" (= (ac.flow 0 Base []) [flow [1] []]))
             (check "flow-idempotent" (= (ac.flow 0 Base [30]) [flow [] []]))
             (check "flow-blank-preference" (= (ac.flow 0 BlankFirst []) [flow [2] []]))
             (check "flow-ambiguity" (= (ac.flow 0 Ambiguous []) [flow [1] [30]]))
             (check "dec-string" (= Round [ok "bread"]))
             (check "dec-list-one" (= OneList [ok ["apple"]]))
             (check "dec-list-empty" (= Empty [ok []]))]
       (if (all-true Results)
           (do (output "ALL PASS~%") true)
           (do (output "SOME FAIL~%") false))))

(run-tests)
