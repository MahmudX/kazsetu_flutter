# KazSetu for Android

Flutter app covering the whole marketplace for both sides:

- **Find**: browse and filter jobs, or talents people offer.
- **Post**: a five-step job wizard (what, pay, when and where, details, photos and publish), and a talent editor.
- **Activity**: the to-do inbox, your applications, your posts with their candidates (shortlist, decline, offer, ask for contact), agreements (meeting place, contact, mark done, review, cancel) and your talents.
- **Messages**: conversations, refreshed every few seconds while a thread is open.
- **Me**: profile and picture, verification (photograph the front and back of an NID or licence), public profile, credits, reports, Bangla/English.

The app talks only to `/api/m` on the server (`kazsetu.Presentation/Controllers/Mobile*.cs`). Those controllers adapt the same services the web pages use, so every rule lives in one place. Sign-in is with a phone number or username and a password. It returns a 1-hour bearer token and a 30-day refresh token, both kept in Android Keystore-backed secure storage.

Credential photos are resized on the phone, then uploaded to the server one side at a time. The server checks the real format, re-encodes the image to JPEG without metadata, and stores it privately. Only a Verifier can view it, each view is recorded, and it is deleted 30 days after the decision.

## Run and build

Needs the Android SDK (`flutter doctor`).

```
flutter run --dart-define=API_BASE=https://kazsetu.com
flutter build apk --release --dart-define=API_BASE=https://kazsetu.com
```

To check smoothness on a real phone, run `flutter run --profile` and open DevTools → Performance, or turn on the performance overlay. Release and profile builds use Impeller, so shaders don't compile at runtime.

Against a local server from the emulator, use `--dart-define=API_BASE=https://10.0.2.2:7118` (the emulator must trust the dev certificate).

`flutter analyze` and `flutter test` check the code, the money and date formatting, and that every UI string has both English and Bangla.

## Not yet done

- A release signing key (release builds still use the debug key).
- Push notifications. The To do tab and open threads refresh themselves.
- Phone-number SMS verification and password reset open the website.
