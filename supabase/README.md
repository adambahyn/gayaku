# Supabase backend

Auth, profiles and avatar storage for GAYAKU. Wardrobe items and looks are
still in memory in the app; they land here once the ML output fields are final.

```
supabase/
  migrations/20261024120000_profiles.sql        profiles table, RLS, sign-up trigger
  migrations/20261024120100_avatars_bucket.sql  private avatars bucket, per-user rules
```

## What the app talks to

`flutter_app/lib/services/auth_service.dart` is the only file that imports the
Supabase SDK. The screens call `authService`, which is:

- `DemoAuthService` by default — accepts any credentials, no network. `flutter
  run` and `flutter test` work with no project configured.
- `SupabaseAuthService` when `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are
  compiled in. `main()` installs it before the first frame.

| Screen | Call |
| --- | --- |
| `login_screen.dart` | `authService.signIn(email:, password:)` |
| `register_screen.dart` | `authService.signUp(email:, password:, displayName:)` |
| `profile_screen.dart` | `authService.currentUser`, `authService.signOut()` |

`AuthException.message` is shown in a SnackBar as-is, so the mapping from
Supabase's English errors to Indonesian copy lives in `_friendly()`.

## First-time setup

1. Create a project at <https://supabase.com/dashboard> (free tier). Note the
   project ref, the API URL and the **publishable** key from *Project Settings →
   API keys* (older projects call it the **anon** key — same slot, same
   behaviour). That key is public by design; RLS is what protects the data.
   Never ship the `secret` / `service_role` key.
2. Apply the migrations. Either paste both files from `migrations/` into the
   dashboard SQL editor in filename order, or use the CLI:

   ```bash
   npx supabase login
   npx supabase link --project-ref <project-ref>
   npx supabase db push
   ```

3. Run the app with the credentials:

   ```bash
   cd flutter_app
   flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
               --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
   ```

   Add the same two `--dart-define` flags to `flutter build apk --release`. A
   build without them silently runs the demo backend.

## Verifying it works

- Sign up in the app, then check *Table Editor → profiles*: one row, with
  `display_name` taken from the sign-up form.
- *Authentication → Users* shows the new user; `email_confirmed_at` is null
  until the confirmation link is clicked, which is why sign-up with email
  confirmation enabled returns to the Sign In screen with a hint.
- In the SQL editor, `select * from profiles;` as the `anon` role returns
  nothing — that is RLS working, not a bug.

## Not covered yet

- Google Sign-In. The button says it is not connected; it needs an OAuth client
  and a redirect URL in the dashboard plus `signInWithOAuth` in
  `SupabaseAuthService`.
- Avatar upload. The bucket and policies exist, no screen writes to it.
- Wardrobe items, looks, favourites. Their columns depend on what the scanner
  emits (category, dominant colour, bbox, confidence), so the tables wait.
- Offline caching and session refresh UI. `supabase_flutter` persists the
  session on disk and refreshes tokens on its own.
