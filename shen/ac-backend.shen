\* Endpoint builders. Layout is the generated Haskell client:

   foods (01-foods):
     addFood  = module 0, endpoint 0, string
     getFoods = module 0, endpoint 1, (no args); response is list of strings

   probe (PingCx Backend.db, generated 2026-08-18):
     findFaultRecommendation = module 0, endpoint 0,
       CustomerID, ClientSiteID, String, String
     linkScenarioRecommendation = module 0, endpoint 1,
       ScenarioID, RecommendationID
   Each UInt64 newtype is length-prefix 8 then u64BE. *\

(define ac.add-food
  Name -> (append (ac.hdr 0 0) (ac.enc-string Name)))

(define ac.get-foods
  -> (ac.hdr 0 1))

(define ac.find-fault
  CustomerID ClientSiteID UnitType ScenarioTitle ->
    (ac.append*
      [(ac.hdr 0 0)
       (ac.enc-u64 CustomerID)
       (ac.enc-u64 ClientSiteID)
       (ac.enc-string UnitType)
       (ac.enc-string ScenarioTitle)]))

(define ac.link-rec
  ScenarioID RecommendationID ->
    (ac.append*
      [(ac.hdr 0 1)
       (ac.enc-u64 ScenarioID)
       (ac.enc-u64 RecommendationID)]))
