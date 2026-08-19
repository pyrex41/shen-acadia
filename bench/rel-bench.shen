(load "../shen-rel/shen/rel.shen")

(define bench-catalog
  -> (rel.add-table (rel.empty) (rel.table "foods" "id" "open" [])))

(define food-name
  I -> (cn "f" (str I)))

(define rel-add-n
  0 W -> W
  N W -> (rel-add-n (- N 1)
                    (rel.must (rel.insert W "foods" [system]
                                          [["name" (food-name N)]]))))

(define rel-names
  W -> (map (/. R (rel.col R "name"))
            (rel.must-rows (rel.access W "foods" [system]))))

(define rel-bench
  N -> (let T0 (get-time run)
            W (rel-add-n N (bench-catalog))
            T1 (get-time run)
            Names (rel-names W)
            T2 (get-time run)
         (do (output (cn "rel-add-sec " (cn (str (- T1 T0)) "~%")))
             (output (cn "rel-get-sec " (cn (str (- T2 T1)) "~%")))
             (output (cn "rel-names " (cn (str (length Names)) "~%")))
             (output "REL DONE~%")
             true)))


