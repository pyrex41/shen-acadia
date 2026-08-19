\* Endpoint builders. Layout is the generated Haskell client:

   foods (01-foods):
     addFood  = module 0, endpoint 6, string
     getFoods = module 0, endpoint 7, (no args); response is list of strings

   probe (PingCx Backend.db, generated 2026-08-18):
     putFaultRecommendation = module 0, endpoint 0,
       RecommendationID, CustomerID, ClientSiteID, String, String, String
     findFaultRecommendation = module 0, endpoint 1,
       CustomerID, ClientSiteID, String, String
     findFaultRecommendationIDs = module 0, endpoint 2,
       CustomerID, ClientSiteID, String, String
     findScenarioRecommendation = module 0, endpoint 3, ScenarioID
     getScenarioRecommendations = module 0, endpoint 4, ScenarioID
     linkScenarioRecommendation = module 0, endpoint 5,
       ScenarioID, RecommendationID
   Each UInt64 newtype is length-prefix 8 then u64BE. *\

(define ac.add-food
  Name -> (append (ac.hdr 0 6) (ac.enc-string Name)))

(define ac.get-foods
  -> (ac.hdr 0 7))

(define ac.put-fault
  RecommendationID CustomerID ClientSiteID UnitType ScenarioTitle Recommendation ->
    (ac.append*
      [(ac.hdr 0 0)
       (ac.enc-u64 RecommendationID)
       (ac.enc-u64 CustomerID)
       (ac.enc-u64 ClientSiteID)
       (ac.enc-string UnitType)
       (ac.enc-string ScenarioTitle)
       (ac.enc-string Recommendation)]))

(define ac.find-fault
  CustomerID ClientSiteID UnitType ScenarioTitle ->
    (ac.append*
      [(ac.hdr 0 1)
       (ac.enc-u64 CustomerID)
       (ac.enc-u64 ClientSiteID)
       (ac.enc-string UnitType)
       (ac.enc-string ScenarioTitle)]))

(define ac.link-rec
  ScenarioID RecommendationID ->
    (ac.append*
      [(ac.hdr 0 5)
       (ac.enc-u64 ScenarioID)
       (ac.enc-u64 RecommendationID)]))

(define ac.find-scenario-rec
  ScenarioID -> (append (ac.hdr 0 3) (ac.enc-u64 ScenarioID)))

(define ac.find-fault-ids
  CustomerID ClientSiteID UnitType ScenarioTitle ->
    (ac.append*
      [(ac.hdr 0 2)
       (ac.enc-u64 CustomerID)
       (ac.enc-u64 ClientSiteID)
       (ac.enc-string UnitType)
       (ac.enc-string ScenarioTitle)]))

(define ac.get-scenario-recs
  ScenarioID -> (append (ac.hdr 0 4) (ac.enc-u64 ScenarioID)))
