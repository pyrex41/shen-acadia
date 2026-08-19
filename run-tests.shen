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
          Unit (ac.dec-unit [0 0 0 0])
          \\ 1-item list: LE count 1, string "apple", LE 0
          OneList (ac.dec-strings
                    (append (ac.u32le 1)
                            (append (ac.enc-string "apple") (ac.u32le 0))))
          Empty (ac.dec-strings (ac.u32le 0))
          Round (ac.dec-string (ac.enc-string "bread"))
          Results
            [(check "add-food-apple"
                    (= AddApple "0000000000000000000000056170706c65"))
             (check "get-foods" (= Get "0000000000000001"))
             (check "find-fault"
                    (= Find
                       "000000000000000000000008000000000000000100000008000000000000000a00000003414855000000084f76657268656174"))
             (check "link-rec"
                    (= Link
                       "000000000000000100000008000000000000001e00000008000000000000005a"))
             (check "dec-unit" (= Unit [ok unit]))
             (check "dec-string" (= Round [ok "bread"]))
             (check "dec-list-one" (= OneList [ok ["apple"]]))
             (check "dec-list-empty" (= Empty [ok []]))]
       (if (all-true Results)
           (do (output "ALL PASS~%") true)
           (do (output "SOME FAIL~%") false))))

(run-tests)
