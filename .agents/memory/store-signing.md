# Store upload: signature check (open since 2026-09-28)
A MinimalFace beta upload failed with "Signature check failed": the local developer_key isn't the key registered to
the Garmin developer account; that key comes from a signed-in SDK Manager session. Check this before the next Store
upload. Store packages: `FaceCore/tools/package.ps1 -Face X` builds `dist/<Name>-<version>.iq`.
