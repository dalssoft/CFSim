globals [
  customer_patches
  feature_patches
  total_market_feature_set_ids
  has_gone_to_market?
  last_backlog_story
  max_initial_feature_set
]

breed [ customers customer ]
breed [ features feature ]
breed [ stories story ]   ; backlog
breed [ feedbacks feedback ]

customers-own [
  feature_wanted
  my_feedback
]

features-own [
  id
  fitness
]

stories-own [
  id
  feedback_count
]

feedbacks-own [
  id
]

to setup
  clear-all
  set max_initial_feature_set 3
  draw-market
  populate-market
  reset-ticks
  set has_gone_to_market? false
  go_to_market
end

to go
  ask customers [
    move
    make_business_contact
  ]
  ask feedbacks [
    move-feedback
    turn-into-story
  ]
  if ticks mod 1000 = 0 [ build_features ]
  tick
end

to go_to_market
  if has_gone_to_market? [stop]
  define-initial-features
  order-features
  order-backlog
  set has_gone_to_market? true
end

to draw-market

  ask patches [ set pcolor white ]

  ; market distance
  set customer_patches patches with [pxcor > -3]
  ask customer_patches [ set pcolor blue ]
  ask patches with [pxcor = (max-pxcor / 2) and pycor = min-pycor] [set plabel "customers"]

  ; company area
  set feature_patches patches with [pxcor < -3]
  ask feature_patches [ set pcolor green ]
  ask patches with [pxcor = (max-pxcor / -2) and pycor = min-pycor] [set plabel "company"]

  ; company external interface (channel)
  ask patches with [pxcor = -3]
    [ set pcolor black ]

end

to-report random-pareto [alpha mm]
  report mm / ( random-float 1 ^ (1 / alpha) )
end

to-report feature-distribution-value
  if (first feature_distribution = "1") [report 1.0]
  if (first feature_distribution = "2") [report .5]
  if (first feature_distribution = "3") [report .2]
end

to populate-market
  create-customers total_market_size [
    set color white
    set size .8
    ; set feature_wanted n-values 3 [random (max_initial_feature_set * feature_set_gap)]
    set feature_wanted n-values 3 [round random-pareto 1 feature-distribution-value]
    set my_feedback [feature_wanted] of self
    move-to-empty-one-of customer_patches
  ]
  set total_market_feature_set_ids remove-duplicates shuffle (reduce sentence ([feature_wanted] of customers))
end

to define-initial-features
  let max_initial_feature_set_length min (list max_initial_feature_set (length total_market_feature_set_ids))
  let initial_feature_set_ids n-values max_initial_feature_set_length [i -> item i total_market_feature_set_ids]

  foreach initial_feature_set_ids [fid ->
    create-features 1 [
      set-feature-details
      set id fid ]
  ]
end

to set-feature-details
  set color blue
  set xcor min-pxcor
  set ycor max-pycor
  set heading 0
  set shape "box"
end

to set-story-details
  set color gray
  set xcor min-pxcor
  set ycor max-pycor
  set heading 0
  set shape "book"
end

to build_features
  let max_stories min (list count stories 3)
  let first_stories sublist ordered-backlog 0 max_stories
  foreach first_stories [s ->
    transform-into-feature s]
  order-features
  order-backlog
end

to transform-into-feature [storie]
  let sid [id] of storie
  ask storie [die]

  if member? sid [id] of features [stop]

  create-features 1 [
    set id sid
    set-feature-details
  ]
end

to move  ; turtle procedure
  lt random-float 20
  rt random-float 20
  ifelse patch-ahead 1 = nobody
         or [pcolor] of patch-ahead 1 = black
      [ lt random-float 360 ]   ;; We see a wall in front of us. Turn a random amount.
      [ fd .1 ]                ;; Otherwise, it is safe to move forward.
end

to move-feedback
  fd .3
  let xlaststory item 0 story-to-follow
  let ylaststory item 1 story-to-follow
  facexy xlaststory ylaststory
end

to turn-into-story

  let xlaststory item 0 story-to-follow
  let ylaststory item 1 story-to-follow
  if not (round [xcor] of self = round xlaststory
    and round [ycor] of self = round ylaststory)
  [ stop ]

  let my_id [id] of self
  let known_story one-of stories with [id = my_id]

  ifelse (known_story = nobody)
  [
    hatch-stories 1 [
      set-story-details
      set id my_id ]
  ]
  [
    ask known_story [
      set feedback_count feedback_count + 1
      set color (feedback_count / 2) + gray
      set label feedback_count
    ]
  ]

  order-backlog
  die

end

to-report story-to-follow
  let xlaststory min-pxcor
  let ylaststory max-pycor
  if not (last_backlog_story = nobody or last_backlog_story = 0) [
    set xlaststory [xcor] of last_backlog_story
    set ylaststory [ycor] of last_backlog_story
  ]

  report (list xlaststory ylaststory)
end

to make_business_contact
  if patch-ahead 1 = nobody [stop]
  if [pcolor] of patch-ahead 1 != black [stop]

  if length [feature_wanted] of self = 3 [set shape "circle"]

  let will_give_feedback? false
  foreach sort features [f ->
    if member? ([id] of f) ([feature_wanted] of self) [
      ask f [set fitness fitness + 1]
      ask self [
        happier-customer [id] of f
      ]
      set will_give_feedback? true
      order-features
    ]
  ]

  ask self [if will_give_feedback? [give-feedback]]
end

to happier-customer [feature_id]
  let i_want_this [feature_wanted] of self
  set i_want_this remove feature_id i_want_this
  set feature_wanted i_want_this

  let i_told_this remove feature_id [my_feedback] of self
  set my_feedback i_told_this

  if length i_want_this = 2 [set shape "face sad"]
  if length i_want_this = 1 [set shape "face neutral"]
  if length i_want_this = 0 [set shape "face happy"]
end

to give-feedback
  if empty? [my_feedback] of self [stop]

  let my_fb one-of ([my_feedback] of self)
  let xlaststory item 0 story-to-follow
  let ylaststory item 1 story-to-follow
  hatch-feedbacks 1 [
    set id my_fb
    facexy xlaststory ylaststory
    set color pink
  ]
  set my_feedback remove my_fb [my_feedback] of self
end

to move-to-empty-one-of [locations]  ;; turtle procedure
  move-to one-of locations
  while [any? other turtles-here and (pcolor = black) ] [
    move-to one-of locations
  ]
end

to order-backlog
  let sorted_stories ordered-backlog
  if sorted_stories = [] [stop]
  let first_story first sorted_stories
  if first_story = nobody [stop]
  ask first_story [
    set xcor min-pxcor
    set ycor max-pycor
  ]
  foreach sorted_stories [s ->
    order-vertically first_story s
    set first_story s
    set last_backlog_story s
  ]

end

to-report ordered-backlog

  ifelse first backlog_prioritization = "2" [
    ; by-customer-feedback
    report sort-on [(- feedback_count)] stories
  ][
    ; random
    report shuffle sort stories
  ]
end

to order-features
  let sorted_features sort-on [(- fitness)] features
  if sorted_features = [] [stop]
  let first_feature first sorted_features
  ask first_feature [
    set xcor (min-pxcor) / 2
    set ycor max-pycor
  ]
  foreach sorted_features [f ->
    order-vertically first_feature f
    set first_feature f
    ask f [update-feature-status]
  ]
end

to order-vertically [previous next]
  if previous = nobody [stop]

  ifelse [ycor] of previous - 2 < min-pycor
    [ask next [
       set ycor max-pycor - 1
       set xcor [xcor] of previous + 1 ]]
    [ask next [
       set ycor [ycor] of previous - 1
       set xcor [xcor] of previous]
  ]
end

to update-feature-status
  set color (fitness / 3) + sky
  set label fitness
end
@#$#@#$#@
GRAPHICS-WINDOW
448
100
946
599
-1
-1
14.85
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
490
11
571
44
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
583
12
646
45
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

PLOT
11
100
283
391
customers
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"happy" 1.0 0 -8862290 true "" "plot count customers with [length feature_wanted = 0]"
"neutral" 1.0 0 -723837 true "" "plot count customers with [length feature_wanted = 1]"
"sad" 1.0 0 -1604481 true "" "plot count customers with [length feature_wanted = 2]"
"not customer" 1.0 0 -5298144 true "" "plot count customers with [length feature_wanted = 3]"
"total" 1.0 0 -16777216 true "" "plot total_market_size"

SLIDER
660
10
922
43
total_market_size
total_market_size
1
1000
1000.0
1
1
people or companies
HORIZONTAL

MONITOR
1236
153
1385
198
features delivered
count features
17
1
11

MONITOR
291
101
441
146
total addressable market
count customers
17
1
11

MONITOR
290
153
442
198
served available market (%)
round (((count customers with [length feature_wanted != 3]) / total_market_size) * 100)
17
1
11

MONITOR
1235
205
1386
250
features in use
count features with [fitness > 0]
17
1
11

MONITOR
1235
99
1386
144
features desired
length total_market_feature_set_ids
17
1
11

PLOT
956
99
1228
401
features
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"delivered" 1.0 0 -3026479 true "" "plot count features"
"in use" 1.0 0 -13840069 true "" "plot count features with [fitness > 0]"
"on backlog" 1.0 0 -2674135 true "" "plot count stories"
"desired" 1.0 0 -16777216 true "" "plot length total_market_feature_set_ids"

MONITOR
1235
258
1387
303
stories on backlog
count stories
17
1
11

MONITOR
291
202
442
247
target market (%)
round (((count customers with [length feature_wanted = 0]) / total_market_size) * 100)
17
1
11

PLOT
11
402
441
598
feedback
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count feedbacks"

CHOOSER
733
49
922
94
backlog_prioritization
backlog_prioritization
"1 - by intuition (random)" "2 - by customer feedback"
0

PLOT
956
405
1383
602
 assets
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"[passive] backlog value" 1.0 0 -16777216 true "" "plot sum [feedback_count] of stories"
"[active] feature value" 1.0 0 -7500403 true "" "plot sum [fitness] of features"

CHOOSER
490
51
728
96
feature_distribution
feature_distribution
"1 - concentrated" "2 - highly concentrated" "3 - extremely concentrated"
0

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

book
false
0
Polygon -7500403 true true 30 195 150 255 270 135 150 75
Polygon -7500403 true true 30 135 150 195 270 75 150 15
Polygon -7500403 true true 30 135 30 195 90 150
Polygon -1 true false 39 139 39 184 151 239 156 199
Polygon -1 true false 151 239 254 135 254 90 151 197
Line -7500403 true 150 196 150 247
Line -7500403 true 43 159 138 207
Line -7500403 true 43 174 138 222
Line -7500403 true 153 206 248 113
Line -7500403 true 153 221 248 128
Polygon -1 true false 159 52 144 67 204 97 219 82

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
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="simulation" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>((count customers with [length feature_wanted = 0]) / total_market_size) &gt; .5</exitCondition>
    <metric>ticks</metric>
    <metric>count customers with [length feature_wanted = 0]</metric>
    <metric>sum [feedback_count] of stories</metric>
    <metric>sum [fitness] of features</metric>
    <enumeratedValueSet variable="total_market_size">
      <value value="10"/>
      <value value="70"/>
      <value value="500"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backlog_prioritization">
      <value value="&quot;1 - by intuition (random)&quot;"/>
      <value value="&quot;2 - by customer feedback&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="feature_distribution">
      <value value="&quot;1 - concentrated&quot;"/>
      <value value="&quot;2 - highly concentrated&quot;"/>
      <value value="&quot;3 - extremely concentrated&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
