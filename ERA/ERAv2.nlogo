__includes ["ERAv2core.nls"]

extensions [ table ]

globals [ eri-currencies ]

breed [ ops-nodes ops-node ]
breed [ proj-investors proj-investor ]

patches-own [
  country
  ecological-health
  cost-of-proj ;; will be in own currency?, so outsiders will have to convert with ERI
  timeframe-of-proj
  true-eco-benefit-from-proj
  proj-counter
  proj-here?
]

proj-investors-own [
  home-country
  cash
  current-projects
  ability
  new-project? ;; if investor got new project in this tick
  completed-projects ;; to factor into ability
  estimated-aiv-potential-project
]


to setup
  clear-all
  set eri-currencies (list)
  setup-ops-nodes
  setup-proj-investors
  setup-patches
  create-ops-nodes 1 [   ;; this is standing in for the decentralized ops-node (like a crypto)
    set color white
    set shape "Circle (2)"
    set size 2
    setxy random-xcor random-ycor
  ]
  reset-ticks
end

to setup-ops-nodes
  foreach n-of 3 base-colors [ c ->   ;; 3 is placeholder for number of jurisdictions
    ask one-of patches [
      sprout-ops-nodes 1 [
        set color c
        set shape "Circle (2)"
        set size 2
      ]
    ]
  ]
end

to setup-proj-investors
  create-proj-investors num-proj-investors [
    set shape "person"
    set color black + 2
    set size 2
    setxy random-xcor random-ycor
    set home-country [who] of min-one-of ops-nodes [distance myself]
    set cash round random-normal 10000 1000
    set ability round random-normal 0.7 0.25
    if ability > 1 [set ability 1]
    if ability < 0.11 [set ability 0.11]
    set current-projects (list)
    set new-project? false
  ]
end

to setup-patches
  ask patches [
    set ecological-health (1 + random 1000)
    set pcolor ([color] of min-one-of ops-nodes [distance myself] + (sqrt (ecological-health)) / 20)
    set country [who] of min-one-of ops-nodes [distance myself]
    set proj-counter 0
    set timeframe-of-proj (2 + random 18)
    set cost-of-proj (round random-normal 200 45) * timeframe-of-proj
    set true-eco-benefit-from-proj round (random-normal 300 40 * timeframe-of-proj - ln(ecological-health))
    set proj-here? false
  ]
end

;; patches only have env health (change to topsoil quant and qual), no need for cost of project etc
;; dim returns for project, function --> given patch's current state, if you were to invest x, that would improve by y in ideal case
;; instead of true aiv, it's an "ideal" aiv --> mean benefit for x amount of resources, incorporating ability
;; ability (mean benefit from given resources)

;; climate characteristics of patch (for later)
;; range of projects instead of one project with fixed benefit
;; code above go is probably not core ERA code

to go
  if (ticks > 0 and ticks mod 20 = 0) [
    core.eco-degradation
  ]

  ask proj-investors [
    core.update-or-complete-project

    set new-project? false
    core.look-for-new-project
    if new-project? = true [
      core.select-min-redemption-price
      core.choose-ops-node
    ]
  ]

  ask ops-nodes [
    core.review-proposals
  ]

  ask proj-investors [
    core.update-project-info
  ]

  tick
end

;to eco-degradation
;  ask patches with [ecological-health > 1][ ;; something that asymptotes, use a function instead of linear
;      set ecological-health (ecological-health - 1)
;      set pcolor ([color] of one-of ops-nodes with [who = [country] of myself] + (sqrt (ecological-health)) / 20)
;    ]
;    ask patches with [proj-here? = false] [
;      set true-eco-benefit-from-proj round (random-normal 300 40 * timeframe-of-proj - ln(ecological-health))
;    ]
;end

;to look-for-new-project
;  if cash >= 100 [
;    let potential-project best-deal-near-me ([ability] of self)
;    ifelse potential-project != nobody [
;      let new-project table:make
;      table:put new-project "project-location" potential-project
;      table:put new-project "project-cost" [cost-of-proj] of potential-project
;      table:put new-project "project-timeframe" [timeframe-of-proj] of potential-project
;      table:put new-project "project-true-eco-benefit" [true-eco-benefit-from-proj] of potential-project
;      table:put new-project "project-investor-estimated-aiv" estimated-aiv-potential-project
;
;      set current-projects fput new-project current-projects
;      move-to table:get new-project "project-location"
;      set new-project? true
;      ask table:get new-project "project-location" [
;        set proj-here? true
;      ]
;    ][
;      set heading random 360 ;; systematic search at some point
;      fd (10 + random 10)
;    ]
;  ]
;end

to-report best-deal-near-me [proj-investor-ability]
  let available-projects patches in-radius 7 with [proj-here? = false and cost-of-proj < [cash] of myself and ecological-health < 2000]
  let estimated-aiv round ((random-normal true-eco-benefit-from-proj true-eco-benefit-from-proj / 4) * (proj-investor-ability)) ;; set scale so no arbitrary multiplicative factors
  let estimated-cost round (cost-of-proj) ;; set estimated aiv similar scale to estimated cost
  let potential-project max-one-of available-projects [estimated-aiv - estimated-cost] ;; reports a patch

;  show [estimated-aiv] of potential-project
;  show [estimated-cost] of potential-project ;; estimated cost (actually doing the project + taxes to pay)
;  show [estimated-aiv - estimated-cost] of potential-project

  if potential-project != nobody [
  ifelse [estimated-aiv - estimated-cost] of potential-project > 0.005 * ([cash] of self) [ ;; 0.01 is arbitrary - saying want a min return of 1% of their wealth
      set estimated-aiv-potential-project [estimated-aiv] of potential-project
      report potential-project
  ] [
    report nobody
    ]
  ]
  report nobody
end


;to select-min-redemption-price
;  let cost table:get item 0 current-projects "project-cost"
;  let time table:get item 0 current-projects "project-timeframe"
;  let estimated-aiv table:get item 0 current-projects "project-investor-estimated-aiv"
;  ;; where the COST stuff comes in, same as selecting price there
;  let min-redemption-price cost + (0.1 * cost) ;; min margin same for everyone, say 10%--> plus or percentage?
;  table:put item 0 current-projects "min-redemption-price" min-redemption-price
;end

;; legal stuff - in some places only certain currencies are allowed

;to choose-ops-node
;  ifelse random 100 < 80 [ ;; instead of random for later, include prediction of relative worth of currencies
;    let proj-ops-node one-of ops-nodes with [who = [home-country] of myself]
;    table:put item 0 current-projects "relevant-ops-node" proj-ops-node
;  ][
;    let proj-ops-node one-of ops-nodes with [who > count proj-investors]
;    table:put item 0 current-projects "relevant-ops-node" proj-ops-node
;  ]
;end


;to review-proposals
;  let agents-with-new-proposals-for-me proj-investors with [new-project? = true and table:get item 0 current-projects "relevant-ops-node" = myself]
;
;  ask agents-with-new-proposals-for-me [
;    let min-redemption-price table:get item 0 current-projects "min-redemption-price"
;    let cost table:get item 0 current-projects "project-cost"
;    let true-eco-benefit table:get item 0 current-projects "project-true-eco-benefit"
;    let time table:get item 0 current-projects "project-timeframe"
;    let current-ecological-health [ecological-health] of table:get item 0 current-projects "project-location"
;
;    let node-estimated-aiv round (random-normal true-eco-benefit true-eco-benefit / 4)
;
;    node-accept-or-reject node-estimated-aiv time current-ecological-health
;    table:put item 0 current-projects "do-project?" false
;
;    if table:get item 0 current-projects "proposal-result" = "accept" [
;      if node-estimated-aiv >= min-redemption-price [
;        accept-project node-estimated-aiv
;      ]
;    ]
;
;; old code with old rules, keeping for reference
;;    if table:get item 0 current-projects "proposal-result" = "accept" [
;;      ifelse random 100 < 70 [ ;; node agrees to proposed redemption price -- fine for random now, put in reporter for whether or not the node agrees (can change into non random for later)
;;        accept-project proposed-redemption-price
;;      ][ ;; else node suggests higher or lower price
;;        let node-redemption-price round random-normal (proposed-redemption-price) (proposed-redemption-price / 4)
;;        ifelse node-redemption-price >= proposed-redemption-price [ ;; agent automatically accepts if new price is higher
;;          accept-project node-redemption-price
;;        ][ ;; else if new price is lower, agent accepts/rejects with randomness
;;          if node-redemption-price > cost and random 100 < 70 [ ;; if these conditions are fulfilled the agent still accepts (shouldn't be random_
;;            accept-project node-redemption-price ;; privately proj investors have minimum price (if less than that then bye)
;;          ] ;; no need to write an else condition because the default do-project? is false
;;        ]
;;      ]
;;    ]
;
;  ]
;end


;to node-accept-or-reject [node-estimated-aiv time current-ecological-health]
;  (ifelse current-ecological-health <= 100 [
;      table:put item 0 current-projects "proposal-result" "accept"
;    ] node-estimated-aiv / time < 150 [
;      table:put item 0 current-projects "proposal-result" "reject"
;    ][ ;; else
;      table:put item 0 current-projects "proposal-result" "accept"
;    ]
;  )
;end

;to accept-project [node-estimated-aiv]
;  table:put item 0 current-projects "node-estimated-aiv" node-estimated-aiv
;  table:put item 0 current-projects "do-project?" true
;end

;to update-project-info
;    if new-project? = true and table:get item 0 current-projects "do-project?" = false [
;      ;; ask patch to set proj-here false if project investor decided to not do project
;      ask table:get item 0 current-projects "project-location" [
;        set proj-here? false
;      ]
;      set new-project? false
;      ;; wipe the project data from current-projects
;      set current-projects remove-item 0 current-projects
;    ]
;    if new-project? = true and table:get item 0 current-projects "do-project?" = true [
;      set cash (cash - table:get item 0 current-projects "project-cost")
;      table:put item 0 current-projects "project-time-elapsed" 0
;    ]
;end


;to update-or-complete-project
;  foreach n-values length current-projects [i -> i] [ n ->
;    let time-now table:get item n current-projects "project-time-elapsed"
;    set time-now (time-now + 1)
;    table:put item n current-projects "project-time-elapsed" time-now ;; can also be a reporter to get diff in time
;  ]
;
;  let to-delete (list)
;
;  foreach n-values length current-projects [i -> i] [ n ->
;    if table:get item n current-projects "project-time-elapsed" = table:get item n current-projects "project-timeframe" [
;      set completed-projects (completed-projects + 1)
;      set to-delete fput n to-delete
;    ] ;; discrete event simulator
;  ]
;  foreach to-delete [ n ->
;    update-stats n
;    set current-projects remove-item n current-projects
;  ]
;end

to update-stats [project]
  ;; update proj-investor cash - this is not core ERA because it's assuming proj investors cash in deposit receipts instantly
  let old-redemption-price table:get item project current-projects "node-estimated-aiv"
  ifelse random 100 < 85 [
    set cash (cash + old-redemption-price)
  ][ ;; with some probability it's a different price because the node reassesses the aiv again
    let new-redemption-price round random-normal old-redemption-price old-redemption-price / 6
    set cash (cash + new-redemption-price)
  ]
  ;; update ability
  if ability < 1 [
    set ability (ability + 0.01)]
  ;; update project status
  let finished-project-location table:get item project current-projects "project-location"
  let finished-project-true-eco-benefit table:get item project current-projects "project-true-eco-benefit"
  ask finished-project-location [
    set ecological-health (ecological-health + finished-project-true-eco-benefit)
    set proj-counter (proj-counter + 1)
    set proj-here? false
    set-new-project
  ]
end

to set-new-project ;; not core
  set cost-of-proj (round random-normal 200 45) * timeframe-of-proj
  set true-eco-benefit-from-proj round (random-normal 300 40 * timeframe-of-proj - ln(ecological-health))
  set pcolor ([color] of one-of ops-nodes with [who = [country] of myself] + (sqrt (ecological-health)) / 20)
end

;; risk assessment (cost of project would be distribution, some projects will have more risk)
;; point assessment ok for first
@#$#@#$#@
GRAPHICS-WINDOW
329
10
766
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
14
19
80
52
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
19
177
52
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
56
61
119
94
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
104
190
137
num-proj-investors
num-proj-investors
0
50
30.0
1
1
NIL
HORIZONTAL

PLOT
4
199
256
328
num projects completed by an investor
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if  min [completed-projects] of proj-investors < max [completed-projects] of proj-investors[\nset-plot-x-range min [completed-projects] of proj-investors max [completed-projects] of proj-investors]"
PENS
"default" 1.0 1 -16777216 true "" "histogram [completed-projects] of proj-investors\n"

PLOT
4
335
257
485
num projects completed on a patch
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "if min [proj-counter] of patches < max [proj-counter] of patches[\nset-plot-x-range min [proj-counter] of patches max [proj-counter] of patches]"
PENS
"default" 1.0 1 -16777216 true "" "histogram [proj-counter] of patches"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle (2)
false
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 15 15 270

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
