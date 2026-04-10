# digitronics-mobile-app

## Deep Links

Android App Links are already declared in the app manifest for `digitronics.ma` and `www.digitronics.ma`.

To fix Google Play Console domain verification, deploy [`.well-known/assetlinks.json`](.well-known/assetlinks.json) to:

- `https://digitronics.ma/.well-known/assetlinks.json`

Before deploying, replace `PLAY_SIGNING_SHA256` with the Play App Signing certificate fingerprint from Play Console.

More details: [`docs/deep-links.md`](docs/deep-links.md)
