# Code signing & notarization

The builds are open-source and reproducible. To ship releases that open with
**zero security warnings**, the maintainer adds signing certificates as GitHub
**repository secrets** — the CI then signs and notarizes automatically. Without
them, CI still produces working *unsigned* builds (Gatekeeper / SmartScreen show
a one-time prompt).

> ⚠️ Real signing requires **paid certificates** — there is no free way to remove
> the OS warnings. Self-signed certificates do **not** satisfy Gatekeeper or
> SmartScreen.

## macOS (Apple notarization)

Requires an **Apple Developer Program** membership ($99/yr) and a
**Developer ID Application** certificate.

Add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12` | base64 of your exported `Developer ID Application` `.p12` |
| `MACOS_CERT_PASSWORD` | password for that `.p12` |
| `MACOS_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `MACOS_NOTARY_APPLE_ID` | your Apple ID email |
| `MACOS_TEAM_ID` | your 10-char Team ID |
| `MACOS_NOTARY_PASSWORD` | an **app-specific password** (appleid.apple.com) |

Export the cert to base64:
```bash
base64 -i DeveloperID.p12 | pbcopy
```

Sign + notarize locally instead of CI:
```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="motionsick-notary" \
./macos/sign-and-notarize.sh 1.0.0
# (create the profile once with: xcrun notarytool store-credentials motionsick-notary ...)
```

## Windows (Authenticode)

Requires a code-signing certificate from a CA (OV or, to skip SmartScreen
reputation build-up, EV).

| Secret | What it is |
|---|---|
| `WINDOWS_CERT_PFX` | base64 of your `.pfx` certificate |
| `WINDOWS_CERT_PASSWORD` | password for the `.pfx` |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.pfx")) | Set-Clipboard
```

## Cutting a signed release

1. Add the secrets above.
2. Push a tag: `git tag v1.0.1 && git push origin v1.0.1`.
3. CI builds, signs, notarizes, and attaches the artifacts to the GitHub Release.
