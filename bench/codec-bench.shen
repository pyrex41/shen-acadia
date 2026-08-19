(load "load.shen")

(define codec-add-n
  0 Acc -> Acc
  N Acc -> (codec-add-n (- N 1) (ac.add-food (cn "f" (str N)))))

(define codec-bench
  N -> (let T0 (get-time run)
            Last (codec-add-n N [])
            T1 (get-time run)
            Hex (ac.hex Last)
            T2 (get-time run)
         (do (output (cn "codec-add-sec " (cn (str (- T1 T0)) "~%")))
             (output (cn "codec-hex-sec " (cn (str (- T2 T1)) "~%")))
             (output (cn "codec-last-len " (cn (str (length Last)) "~%")))
             (output "CODEC DONE~%")
             true)))
