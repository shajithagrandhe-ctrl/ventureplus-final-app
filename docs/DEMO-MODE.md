# Venture Plus authenticated demo mode

The demo APK authenticates with the existing backend first, then switches the
authenticated session to an isolated local repository containing fictional
records. The backend is never used for demo reads or writes after the identity
and role have been verified.

Build the explicit debug demo APK with:

```powershell
.\scripts\mobile.ps1 -Action demo-build -FlutterPath 'C:\Users\shaji\Downloads\flutter\flutter\bin\flutter.bat'
```

The `demo-build` action sets `ENABLE_AUTHENTICATED_DEMO=true`. Normal `build`
and `release` actions keep the existing connected-repository behavior.

The demo repository uses a separate local storage key and role-scopes records
to the authenticated Admin, Employee, or Customer role. The app labels this
state `Authenticated Demo`; logout still clears the authenticated session and
local session markers. No demo record is sent to the production API or
database.

If backend authentication fails, the app reports the failure and does not
silently switch to demo data.
