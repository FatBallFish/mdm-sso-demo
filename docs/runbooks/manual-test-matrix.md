# Manual Test Matrix

## Current slice

1. Start the demo IDP and confirm `GET /api/health` returns `{"status":"ok"}`.
2. Log in with `demo.user / DemoPass123!` and confirm the response contains subject `demo.user`.
3. Log in with `it.admin / AdminPass123!` and confirm the response contains subject `it.admin`.
4. Log in with an invalid password and confirm the response is HTTP `401`.
5. Run `./scripts/install-jamf-style-demo.sh --dry-run` and confirm it lists the target loginwindow paths.
6. Run `./scripts/uninstall-jamf-style-demo.sh --dry-run` and confirm it lists cleanup actions.
7. Run `./scripts/start-login-shell.sh` and confirm a native macOS window opens with SSO login shell text.
8. In the shell, sign in with a seeded account and confirm that an unmapped account transitions to the binding screen.
9. In the shell, bind an existing local short name or create a suggested short name and confirm the UI transitions to success.
10. Disable network in the shell toggle and confirm cached offline login works after one successful online login.
11. Run `bash scripts/tests/login_broker_smoke.sh` and confirm the broker first returns `promptForAccountBinding` and then `allowLogin` after a mapping is created.
12. Run `bash scripts/tests/plugin_bundle_smoke.sh` and confirm the generated plug-in bundle contains `Contents/Info.plist` and an executable binary.
13. Run `bash scripts/tests/install_root_smoke.sh` and confirm a full staging install succeeds into a temp root.
14. Run `bash scripts/tests/uninstall_root_smoke.sh` and confirm staged artifacts are removed again.
15. Run `bash scripts/tests/authdb_transform_smoke.sh` and confirm the generated rule inserts `DemoLoginPlugin:login` after `loginwindow:login`.
16. Run `bash scripts/tests/authdb_restore_smoke.sh` and confirm a backup plist can be restored to an output plist byte-for-byte.

## Planned next slice

1. Bind an SSO subject to an existing local account.
2. Create a new local account when no mapping exists.
3. Allow offline login within a 7-day grace period.
4. Trigger local password sync after successful online login.
5. Restore the native loginwindow auth chain after uninstall.
