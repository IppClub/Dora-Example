-- Human-owned asset profiles: meters, Y up, gameplay forward -Z.
return {
  Fox={path='assets/Fox.glb',unitsToMeters=.01,rotation={0,180,0},targetHeight=.75,
    maxFootprint={1.9,1.9},maxSourceExtent=1000,groundTolerance=.06,
    collider={radius=.95,height=.9},animations={idle='Survey',walk='Walk',run='Run'}},
  cube={path='assets/cube.glb',unitsToMeters=1,rotation={0,0,0},targetHeight=1,
    maxFootprint={1.1,1.1},collider={radius=.75,height=1.1},animations={}}
}
