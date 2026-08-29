# WeddingOS Organizer App

## Public Supabase Configuration

The organizer app requires publishable Supabase configuration at build/run
time. It does not contain a local or production fallback:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=http://10.0.2.2:54321 `
  --dart-define=SUPABASE_ANON_KEY=<local-publishable-or-anon-key> `
  --dart-define=GOOGLE_WEB_CLIENT_ID=<google-web-client-id>
```

Use `http://localhost:54321` for desktop or web access to the local stack. The
Android emulator uses `10.0.2.2` to reach the host. These values are public
client configuration, but environment-specific values must still be supplied by
the build pipeline. Never pass or embed a service-role key in Flutter.

Missing or malformed values produce a bounded deployment-configuration screen;
the app does not print the supplied key.

## Google Sign-In

Native Google Sign-In requires the public Web OAuth client ID at build time as
`GOOGLE_WEB_CLIENT_ID`. On Android and iOS, `google_sign_in` is initialized
with that value as `serverClientId` before interactive authentication. The app
fails closed with bounded configuration copy when it is absent. The client ID
is public configuration; never provide an OAuth client secret or service-role
key to Flutter. The staging/release slice must also provide the Android/iOS/Web
OAuth client configuration, allowed redirects, signing fingerprints, and the
matching Supabase Google provider settings.

The local email/password developer path remains available for local fixtures.
