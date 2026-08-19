\* Acadia endpoint codec, transcribed from generated Haskell (Acadia 0.3.0
   `make --gen-haskell`). That compiler output is not in this repo.

   Request:  u32BE module | u32BE endpoint | args
   String:   u32BE byte-count | utf8 bytes
   UInt64:   u32BE 8 | u64BE value
   Unit:     i32BE 0
   String r: i32BE n (n>=0) | n utf8 bytes
   List:     repeated (u32LE count | count items) terminated by u32LE 0

   POST /_endpoints  Content-Type + Accept: application/octet-stream *\

(define ac.idiv
  N D -> (simple-error "ac.idiv: negative dividend") where (< N 0)
  N D -> (simple-error "ac.idiv: non-positive divisor") where (<= D 0)
  N D -> (ac.idiv-powers N D D 1 []))

(define ac.idiv-powers
  N D P Q Powers -> (ac.idiv-acc N Powers 0) where (> P N)
  N D P Q Powers -> (ac.idiv-powers N D (* P 2) (* Q 2) [[P Q] | Powers]))

(define ac.idiv-acc
  N [] Q -> Q
  N [[P Add] | Powers] Q ->
    (if (>= N P)
        (ac.idiv-acc (- N P) Powers (+ Q Add))
        (ac.idiv-acc N Powers Q)))

(define ac.irem
  N D -> (- N (* (ac.idiv N D) D)))

(define ac.u32be
  N -> (simple-error "ac.u32be: out of range") where (or (< N 0) (> N 4294967295))
  N -> (let B0 (ac.idiv N 16777216)
            R0 (- N (* B0 16777216))
            B1 (ac.idiv R0 65536)
            R1 (- R0 (* B1 65536))
            B2 (ac.idiv R1 256)
            B3 (- R1 (* B2 256))
         [B0 B1 B2 B3]))

(define ac.u32le
  N -> (let BE (ac.u32be N)
         [(nth 4 BE) (nth 3 BE) (nth 2 BE) (nth 1 BE)]))

(define ac.u64be
  [u64 Hi Lo] -> (append (ac.u32be Hi) (ac.u32be Lo))
  N -> (simple-error "ac.u64be: out of exact numeric range")
    where (or (< N 0) (> N 9007199254740991))
  N -> (let Hi (ac.idiv N 4294967296)
             Lo (ac.irem N 4294967296)
          (append (ac.u32be Hi) (ac.u32be Lo))))

(define ac.strlen
  "" -> 0
  S -> (+ 1 (ac.strlen (tlstr S))))

(define ac.utf8-code
  C -> [C] where (<= C 127)
  C -> [(+ 192 (ac.idiv C 64))
        (+ 128 (ac.irem C 64))]
    where (<= C 2047)
  C -> (simple-error "ac.utf8: surrogate code point")
    where (and (>= C 55296) (<= C 57343))
  C -> [(+ 224 (ac.idiv C 4096))
        (+ 128 (ac.irem (ac.idiv C 64) 64))
        (+ 128 (ac.irem C 64))]
    where (<= C 65535)
  C -> [(+ 240 (ac.idiv C 262144))
        (+ 128 (ac.irem (ac.idiv C 4096) 64))
        (+ 128 (ac.irem (ac.idiv C 64) 64))
        (+ 128 (ac.irem C 64))]
    where (<= C 1114111)
  _ -> (simple-error "ac.utf8: code point out of range"))

(define ac.utf8
  "" -> []
  S -> (append (ac.utf8-code (string->n (pos S 0))) (ac.utf8 (tlstr S))))

(define ac.enc-string
  S -> (let Bytes (ac.utf8 S)
         (append (ac.u32be (length Bytes)) Bytes)))

(define ac.enc-u64
  N -> (append (ac.u32be 8) (ac.u64be N)))

(define ac.hdr
  Mod Ep -> (append (ac.u32be Mod) (ac.u32be Ep)))

(define ac.append*
  [] -> []
  [X | Xs] -> (append X (ac.append* Xs)))

\\ -- decode -----------------------------------------------------------------

(define ac.u32be-val
  B0 B1 B2 B3 -> (+ (* B0 16777216) (+ (* B1 65536) (+ (* B2 256) B3))))

(define ac.take-u32be
  [B0 B1 B2 B3 | Rest] -> [(ac.u32be-val B0 B1 B2 B3) Rest]
  _ -> (simple-error "ac.take-u32be: short"))

(define ac.take-u64be
  [A B C D E F G H | Rest] ->
    (let Hi (ac.u32be-val A B C D)
         Lo (ac.u32be-val E F G H)
      [(if (<= Hi 2097151) (+ (* Hi 4294967296) Lo) [u64 Hi Lo]) Rest])
  _ -> (simple-error "ac.take-u64be: short"))

(define ac.take-i32be
  Bs -> (let P (ac.take-u32be Bs)
             N (hd P)
          [(if (>= N 2147483648) (- N 4294967296) N) (hd (tl P))]))

(define ac.take-u32le
  [B0 B1 B2 B3 | Rest] -> [(ac.u32be-val B3 B2 B1 B0) Rest]
  _ -> (simple-error "ac.take-u32le: short"))

(define ac.take-n
  0 Rest -> [[] Rest]
  N Rest -> (ac.take-n-h N Rest []))

(define ac.take-n-h
  0 Rest Acc -> [(reverse Acc) Rest]
  _ [] _ -> (simple-error "ac.take-n: short")
  N [B | Bs] Acc -> (ac.take-n-h (- N 1) Bs [B | Acc]))

(define ac.utf8-cont?
  B -> (and (>= B 128) (<= B 191)))

(define ac.take-utf8-one
  [B | Rest] -> [(n->string B) Rest] where (<= B 127)
  [B C | Rest] ->
    [(n->string (+ (* (- B 192) 64) (- C 128))) Rest]
    where (and (and (>= B 194) (<= B 223)) (ac.utf8-cont? C))
  [B C D | Rest] ->
    [(n->string (+ (* (- B 224) 4096)
                   (+ (* (- C 128) 64) (- D 128)))) Rest]
    where (and (and (>= B 224) (<= B 239))
               (and (ac.utf8-cont? C) (ac.utf8-cont? D)))
  [B C D E | Rest] ->
    [(n->string (+ (* (- B 240) 262144)
                   (+ (* (- C 128) 4096)
                      (+ (* (- D 128) 64) (- E 128))))) Rest]
    where (and (and (>= B 240) (<= B 244))
               (and (ac.utf8-cont? C)
                    (and (ac.utf8-cont? D) (ac.utf8-cont? E))))
  _ -> (simple-error "ac.take-utf8-one: invalid UTF-8"))

(define ac.take-utf8
  0 Rest -> ["" Rest]
  N Rest -> (let P (ac.take-utf8-one Rest)
                 Q (ac.take-utf8 (- N 1) (hd (tl P)))
              [(cn (hd P) (hd Q)) (hd (tl Q))]))

(define ac.bytes->utf8
  [] -> ""
  Bs -> (let P (ac.take-utf8-one Bs)
          (cn (hd P) (ac.bytes->utf8 (hd (tl P))))))

(define ac.dec-unit
  Bs -> (let P (ac.take-i32be Bs)
          (if (= (hd P) 0)
              [ok unit]
              [fail "unit: non-zero"])))

(define ac.dec-u64
  Bs -> (let P (ac.take-sized-u64 Bs)
          [ok (hd P)]))

(define ac.take-sized-u64
  Bs -> (let P (ac.take-i32be Bs)
          (if (= (hd P) 8)
              (ac.take-u64be (hd (tl P)))
              (simple-error "uint64: length is not eight"))))

(define ac.dec-string
  Bs -> (let P (ac.take-i32be Bs)
             N (hd P)
          (if (< N 0)
              [fail "string: negative length"]
              (let Q (ac.take-n N (hd (tl P)))
                [ok (ac.bytes->utf8 (hd Q))]))))

(define ac.dec-strings
  Bs -> (ac.dec-strings-h Bs []))

(define ac.dec-strings-h
  Bs Acc ->
    (let P (ac.take-u32le Bs)
         N (hd P)
         Rest (hd (tl P))
      (if (= N 0)
          [ok (reverse Acc)]
          (ac.dec-strings-chunk N Rest Acc))))

(define ac.dec-strings-chunk
  0 Rest Acc -> (ac.dec-strings-h Rest Acc)
  N Rest Acc ->
    (let S (ac.dec-string Rest)
      (if (= (hd S) ok)
          (ac.dec-strings-chunk (- N 1) (ac.skip-string Rest) [(hd (tl S)) | Acc])
          S)))

(define ac.dec-u64s
  Bs -> (ac.dec-u64s-h Bs []))

(define ac.dec-u64s-h
  Bs Acc ->
    (let P (ac.take-u32le Bs)
         N (hd P)
         Rest (hd (tl P))
      (if (= N 0)
          [ok (reverse Acc)]
          (ac.dec-u64s-chunk N Rest Acc))))

(define ac.dec-u64s-chunk
  0 Rest Acc -> (ac.dec-u64s-h Rest Acc)
  N Rest Acc ->
    (let P (ac.take-sized-u64 Rest)
      (ac.dec-u64s-chunk (- N 1) (hd (tl P)) [(hd P) | Acc])))

(define ac.skip-string
  Bs -> (let P (ac.take-i32be Bs)
             N (hd P)
             Q (ac.take-n N (hd (tl P)))
          (hd (tl Q))))

\\ -- hex (selftest / goldens) ----------------------------------------------

(define ac.hex-digit
  N -> (pos "0123456789abcdef" N))

(define ac.hex-byte
  N -> (let Hi (ac.idiv N 16)
         (cn (ac.hex-digit Hi) (ac.hex-digit (- N (* Hi 16))))))

(define ac.hex
  [] -> ""
  [B | Bs] -> (cn (ac.hex-byte B) (ac.hex Bs)))

\\ -- files ------------------------------------------------------------------

(define ac.write-bin
  Path Bytes ->
    (let S (open Path out)
      (do (ac.write-all S Bytes)
          (close S)
          Path)))

(define ac.write-all
  S [] -> []
  S [B | Bs] -> (do (write-byte B S) (ac.write-all S Bs)))

(define ac.read-bin
  Path ->
    (let S (open Path in)
      (ac.read-all S)))

(define ac.read-all
  S -> (let B (trap-error (read-byte S) (/. E -1))
         (if (or (= B -1) (= B eof))
             (do (close S) [])
             [B | (ac.read-all S)])))
