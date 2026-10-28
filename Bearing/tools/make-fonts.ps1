# Generates this face's bitmap fonts for every screen size (sizes and glyphs in
# tools/font-table.ps1) with the shared generator, FaceCore/tools/make-fonts.ps1.
#
#   powershell -ExecutionPolicy Bypass -File tools\make-fonts.ps1
& (Join-Path $PSScriptRoot '..\..\FaceCore\tools\make-fonts.ps1') -Face (Split-Path -Parent $PSScriptRoot)
