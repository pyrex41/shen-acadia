\* Acadia endpoint codec, transcribed from generated Haskell (Acadia 0.3.0
   `make --gen-haskell`). That compiler output is not in this repo.

   Request:  u32BE module | u32BE endpoint | args
   String:   u32BE char-count | utf8 bytes   (getSizeString = Text.length)
   UInt64:   u32BE 8 | u64BE value
   Unit:     i32BE 0
   String r: i32BE n (n>=0) | n utf8 bytes
   List:     repeated (u32LE count | count items) terminated by u32LE 0

   POST /_endpoints  Content-Type + Accept: application/octet-stream *\

(define ac.idiv
  N D -> 0 where (> D N)
  N D -> 0 where (= N 0)
  N D -> (ac.idiv-loop N D 0))

(define ac.idiv-loop
  N D Q -> (let Q1 (+ Q 1)
                P (* Q1 D)
             (if (> P N) Q (ac.idiv-loop N D Q1))))

(define ac.u32be
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
  N -> (append [0 0 0 0] (ac.u32be N)))

(define ac.strlen
  "" -> 0
  S -> (+ 1 (ac.strlen (tlstr S))))

(define ac.utf8
  "" -> []
  S -> [(string->n (pos S 0)) | (ac.utf8 (tlstr S))])

(define ac.enc-string
  S -> (append (ac.u32be (ac.strlen S)) (ac.utf8 S)))

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

(define ac.take-i32be
  Bs -> (ac.take-u32be Bs))

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

(define ac.bytes->str
  [] -> ""
  [B | Bs] -> (cn (n->string B) (ac.bytes->str Bs)))

(define ac.dec-unit
  Bs -> (let P (ac.take-i32be Bs)
          (if (= (hd P) 0)
              [ok unit]
              [fail "unit: non-zero"])))

(define ac.dec-string
  Bs -> (let P (ac.take-i32be Bs)
             N (hd P)
          (if (< N 0)
              [fail "string: negative length"]
              (let Q (ac.take-n N (hd (tl P)))
                [ok (ac.bytes->str (hd Q))]))))

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
