# The faces
Every face is its own app (own manifest and app id) on the shared FaceCore, targeting the 66 round watches
(`FaceCore/AGENTS.md`).
- Older faces without their own AGENTS.md: MinimalFace (minimal AMOLED, one ring, 2 fields), PulseRings (steps and
  Body Battery rings), TrainingPulse (6-field data grid), GoalBars (activity bars, Stacked/Classic layouts, pace
  markers; calories = active kcal, total minus the BMR share so far).
- Meridian, Tide, Terrain, Bloom come from the Meridian canvas. FlatRate, LugStar, ObdScanner, SocketSet,
  TachCluster are the Shop Floor family (for mechanics). TwistSwitch is a bike watch app, not a face.
- ApexFace is the reference face (hands off, see apexface-hands-off.md).
- Faces with a `demo.jungle` render fixed demo data for screenshots; never ship a demo build. Keep Always-On lit < 10 %.
