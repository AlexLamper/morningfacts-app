# MorningFacts

Learn one small thing every morning. A one-minute fact, picked for the topics you like and pitched at your level, with a one-question check afterwards.

- Flutter app in `morningfacts_mobile/` (iOS, Android)
- Languages: English and Dutch (UI strings in `lib/l10n.dart`, fact texts in `assets/content/facts.json`)
- No account: preferences, streak and levels live on the device
- Premium through RevenueCat (entitlement `premium`, offering with annual, monthly and lifetime packages)

## How it works

| Part | Where |
| --- | --- |
| Onboarding: language, 5+ topics, level per topic, daily goal + reminder | `lib/screens/onboarding.dart` |
| Today: fact card, feedback (like, dislike, too easy, too hard, save), check question | `lib/screens/today.dart` |
| Explore, Saved, Me, bottom navigation | `lib/screens/tabs.dart` |
| Paywall (soft, 1 free fact a day) | `lib/screens/paywall.dart` |
| Personalisation: interest scores, levels, picking the next fact | `lib/logic/picker.dart` |
| Stored state | `lib/state/app_state.dart` |
| Morning reminder (local notification) | `lib/services/reminders.dart` |

Interest: picked topics start at 1.0, others at 0.2. Like +0.3, save +0.2, dislike -0.4, never below 0.05. 10% of picks explore a random topic. Level 1-5 per topic goes up on "too easy" or 3 right answers in a row, down on "too hard" or 2 wrong.

## Adding facts

Add an entry to `assets/content/facts.json` with `en` and `nl` texts, 4 options and the `answer` index. `flutter test` checks that every topic has facts and every fact has both languages.

## Run and test

```bash
cd morningfacts_mobile
flutter pub get
flutter run
flutter test
flutter test test_screens --update-goldens   # renders every screen to test_screens/shots/
```

## Release (iOS)

Every push to `main` that touches `morningfacts_mobile/` builds and uploads a TestFlight build (`.github/workflows/ios-release.yml`, same flow as BijbelQuiz). Repository secrets needed:

`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` (all the same values as BijbelQuiz). Optional: `REVENUECAT_APPLE_KEY` - without it the build works but purchases are off.

No provisioning profile secret: Xcode creates the App Store profile itself with the API key (`-allowProvisioningUpdates`). The API key needs the Admin or App Manager role.

Bundle id: `com.morningfacts.app`.
