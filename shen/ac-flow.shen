(define ac.row-customer
  [candidate Customer _ _ _ _ _ _ _ _] -> Customer)

(define ac.row-site
  [candidate _ Site _ _ _ _ _ _ _] -> Site)

(define ac.row-psi
  [candidate _ _ PSI _ _ _ _ _ _] -> PSI)

(define ac.row-scenario
  [candidate _ _ _ _ Scenario _ _ _ _] -> Scenario)

(define ac.row-title
  [candidate _ _ _ _ _ Title _ _ _] -> Title)

(define ac.row-status
  [candidate _ _ _ _ _ _ Status _ _] -> Status)

(define ac.row-unit
  [candidate _ _ _ _ _ _ _ Unit _] -> Unit)

(define ac.row-ordinal
  [candidate _ _ _ _ _ _ _ _ Ordinal] -> Ordinal)

(define ac.member?
  _ [] -> false
  X [X | _] -> true
  X [_ | Rest] -> (ac.member? X Rest))

(define ac.flow-eligible?
  Scope Row ->
    (and (= 2 (ac.row-status Row))
         (or (= Scope 0) (= Scope (ac.row-psi Row)))))

(define ac.flow-find
  _ [] -> false
  Scenario [Row | _] -> Row where (= Scenario (ac.row-scenario Row))
  Scenario [_ | Rest] -> (ac.flow-find Scenario Rest))

(define ac.flow-replace
  _ _ [] -> []
  Scenario Row [Prior | Rest] -> [Row | Rest]
    where (= Scenario (ac.row-scenario Prior))
  Scenario Row [Prior | Rest] ->
    [Prior | (ac.flow-replace Scenario Row Rest)])

(define ac.flow-ambiguous
  Scenario Ambiguous -> Ambiguous where (ac.member? Scenario Ambiguous)
  Scenario Ambiguous -> (append Ambiguous [Scenario]))

(define ac.flow-choose
  Rows Scope -> (ac.flow-choose-h Rows Scope [] []))

(define ac.flow-choose-h
  [] _ Chosen Ambiguous -> [Chosen Ambiguous]
  [Row | Rest] Scope Chosen Ambiguous ->
    (ac.flow-choose-h Rest Scope Chosen Ambiguous)
    where (not (ac.flow-eligible? Scope Row))
  [Row | Rest] Scope Chosen Ambiguous ->
    (let Scenario (ac.row-scenario Row)
         Prior (ac.flow-find Scenario Chosen)
      (ac.flow-choose-row Rest Scope Row Prior Chosen Ambiguous)))

(define ac.flow-choose-row
  Rest Scope Row false Chosen Ambiguous ->
    (ac.flow-choose-h Rest Scope (append Chosen [Row]) Ambiguous)
  Rest Scope Row Prior Chosen Ambiguous ->
    (ac.flow-choose-h
      Rest
      Scope
      (ac.flow-replace (ac.row-scenario Row) Row Chosen)
      Ambiguous)
    where (and (= "" (ac.row-unit Prior)) (not (= "" (ac.row-unit Row))))
  Rest Scope Row Prior Chosen Ambiguous ->
    (ac.flow-choose-h
      Rest
      Scope
      Chosen
      (ac.flow-ambiguous (ac.row-scenario Row) Ambiguous))
    where (and (not (= "" (ac.row-unit Prior)))
               (and (not (= "" (ac.row-unit Row)))
                    (not (= (ac.row-unit Prior) (ac.row-unit Row)))))
  Rest Scope _ _ Chosen Ambiguous ->
    (ac.flow-choose-h Rest Scope Chosen Ambiguous))

(define ac.flow-ordinals
  [] _ -> []
  [Row | Rest] Linked -> (ac.flow-ordinals Rest Linked)
    where (= "" (ac.row-unit Row))
  [Row | Rest] Linked -> (ac.flow-ordinals Rest Linked)
    where (ac.member? (ac.row-scenario Row) Linked)
  [Row | Rest] Linked ->
    [(ac.row-ordinal Row) | (ac.flow-ordinals Rest Linked)])

(define ac.flow
  Scope Rows Linked ->
    (let Picked (ac.flow-choose Rows Scope)
         Chosen (hd Picked)
         Ambiguous (hd (tl Picked))
      [flow (ac.flow-ordinals Chosen Linked) Ambiguous]))

(define ac.flow-print-values
  _ [] -> []
  Label [Value | Rest] ->
    (do (output (cn Label (cn " " (cn (str Value) "~%"))))
        (ac.flow-print-values Label Rest)))

(define ac.flow-print
  [flow Ordinals Ambiguous] ->
    (do (ac.flow-print-values "CANDIDATE" Ordinals)
        (ac.flow-print-values "AMBIGUOUS" Ambiguous)
        (output "FLOW-END~%")))
