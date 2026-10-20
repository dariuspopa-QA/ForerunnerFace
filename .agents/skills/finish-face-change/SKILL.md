---
name: finish-face-change
description: Finish any change to a ForerunnerFace watch face before reporting it done - run its tests, update CHANGELOG and store description, regenerate store screenshots. Use after editing a face's look, settings or features.
---

# Finish a face change

Run from the repo root (`C:\WORK\ForerunnerFace`) in PowerShell, with the Connect IQ simulator open and visible.
Never for ApexFace (hands off). Never run two simulator scripts at once.

1. Tests on the watch matrix: `FaceCore\tools\run-device-tests.ps1 -Face <Face>` (add `-Devices fr970` for a quick
   pass while iterating; run the full matrix before done). If FaceCore changed, test every face that uses it.
2. `<Face>\CHANGELOG.md`: add the change under the next version; bump `version` in `<Face>\manifest.xml` if releasing.
3. `<Face>\store\description.txt`: make it describe what the face now does (keep the `{{WATCHES}}` block).
4. Screenshots: `FaceCore\tools\store-shots.ps1 -Face <Face>` (shots listed in `<Face>\store\store-config.ps1`),
   and `FaceCore\tools\capture-screens.ps1 -Face <Face>` when the layout changes per screen size.
5. Look at the new images in `<Face>\store\` and compare them with the design mock; fix before reporting.
6. Commit only the paths you changed (`git add <paths>`, never `git add -A`).
