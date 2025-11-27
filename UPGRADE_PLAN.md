# OAuth Migration Plan for Spotiqueue

## Current State

The app has **two separate authentication systems**:

1. **SpotifyWebAPI (Swift)** - Already uses OAuth PKCE via `AuthorizationCodeFlowPKCEManager`
   - Handles searching, browsing, metadata
   - Stores auth tokens in keychain (`spotiqueue_authorization_manager_v2`)
   - Works via `spotiqueue://callback` URL scheme

2. **librespot (Rust)** - Uses deprecated username/password
   - Handles actual audio playback
   - Separate login window (`RBLoginWindow`) collects credentials
   - Stores username/password in keychain separately

**Problem**: Spotify deprecated username/password auth. librespot 0.8.0 now requires OAuth.

## Goal

Unify auth: Use SpotifyWebAPI's OAuth token for librespot, eliminating the username/password flow entirely.

---

## Phase 1: Upgrade Swift Dependencies

### 1.1 Update SpotifyAPI Package
- Current: pinned to specific commit `e814a98f7d...`
- Target: `4.0.2` (latest as of May 2025)
- Update in Xcode: File → Packages → Update to Latest Package Versions
- Or edit dependency to use version requirement `from: "4.0.0"`

### 1.2 Verify OAuth Scopes
Current scopes in `RBSpotifyAPI.swift:183-193`:
```swift
.userReadPlaybackState,
.userModifyPlaybackState,
.playlistModifyPrivate,
.playlistModifyPublic,
.playlistReadPrivate,
.playlistReadCollaborative,
.userLibraryRead,
.userLibraryModify,
.userReadEmail,
```

**Need to add**: `.streaming` scope for librespot playback

### 1.3 Expose Access Token
Add method to `RBSpotifyAPI` to retrieve the current access token:
```swift
func getAccessToken() -> String? {
    return api.authorizationManager.accessToken
}
```

---

## Phase 2: Refactor Rust Worker (librespot)

### 2.1 Change FFI Interface
Replace:
```rust
pub extern "C" fn spotiqueue_login_worker(
    username_raw: *const c_char,
    password_raw: *const c_char,
) -> InitializationResult
```

With:
```rust
pub extern "C" fn spotiqueue_login_worker(
    access_token_raw: *const c_char,
) -> InitializationResult
```

### 2.2 Update Session Creation
Old pattern (librespot 0.3.x):
```rust
let credentials = Credentials::with_password(username, password);
let session = Session::connect(session_config, credentials, None).await;
```

New pattern (librespot 0.8.x):
```rust
let credentials = Credentials::with_access_token(access_token);
let session = Session::new(session_config, None);
session.connect(credentials, false).await?;
```

### 2.3 Update Player Creation
Old:
```rust
let (player, _) = Player::new(player_config, session.clone(), None, move || { ... });
```

New:
```rust
let player = Player::new(
    player_config,
    session.clone(),
    Box::new(NoOpVolume),  // or a real VolumeGetter
    move || { backend(None, audio_format) }
);
```

### 2.4 Fix PlayerEvent Handling
Changes in librespot 0.8.0:
- `Paused`/`Playing`: no longer have `duration_ms` field
- `Changed` → `TrackChanged`
- `Started` → removed
- `VolumeSet` → `VolumeChanged`
- New events: `PlayRequestIdChanged`, `PositionCorrection`, `PositionChanged`, `Seeked`

### 2.5 Fix Track ID Types
- `SpotifyId` → `SpotifyUri`
- Use `SpotifyUri::from_uri(str)` to parse
- `SpotifyUri::Track { id }` for track URIs

---

## Phase 3: Refactor Swift UI

### 3.1 Remove Login Window
- Delete or repurpose `RBLoginWindow.swift` and `RBLoginWindow.xib`
- Remove `RBSecrets.Secret.username` and `.password` cases
- Clean up keychain of old username/password entries

### 3.2 Update AppDelegate Launch Flow
Current flow:
```
applicationDidFinishLaunching
  → Show RBLoginWindow sheet
  → User enters username/password
  → Call spotiqueue_login_worker(username, password)
  → On success, dismiss sheet and initialize SpotifyWebAPI
```

New flow:
```
applicationDidFinishLaunching
  → Check if SpotifyWebAPI is authorized
  → If not: trigger OAuth (opens browser)
  → Once authorized: get access token, call spotiqueue_login_worker(access_token)
  → Continue app initialization
```

### 3.3 Handle Token Refresh
SpotifyWebAPI auto-refreshes tokens, but librespot session may need reconnection.

Options:
a) Subscribe to `authorizationManagerDidChange` and re-init librespot when token refreshes
b) Implement token refresh callback in Rust worker
c) Simply restart playback session on auth errors (simplest)

Recommend option (a) initially.

---

## Phase 4: Keychain Cleanup

### 4.1 Remove Deprecated Secrets
- `spotiqueue_username` - no longer needed
- `spotiqueue_password` - no longer needed

### 4.2 Keep OAuth Token Storage
- `spotiqueue_authorization_manager_v2` - still used by SpotifyWebAPI

---

## Phase 5: Testing

### 5.1 Fresh Install Test
- Remove all keychain entries
- Launch app
- Verify OAuth flow works end-to-end
- Verify playback works with OAuth token

### 5.2 Upgrade Test
- Existing user with old username/password stored
- Launch upgraded app
- Verify graceful migration to OAuth
- Verify old credentials cleaned up

### 5.3 Token Refresh Test
- Play for >1 hour (token expires)
- Verify automatic refresh
- Verify playback continues or reconnects

---

## File Changes Summary

| File | Action |
|------|--------|
| `spotiqueue_worker/Cargo.toml` | ✅ Done - dependencies upgraded |
| `spotiqueue_worker/src/lib.rs` | Refactor for OAuth + librespot 0.8 API |
| `Spotiqueue/Classes/RBSpotifyAPI.swift` | Add `.streaming` scope, expose access token |
| `Spotiqueue/Classes/RBSecrets.swift` | Remove username/password cases |
| `Spotiqueue/RBLoginWindow.swift` | Delete or convert to OAuth status display |
| `Spotiqueue/RBLoginWindow.xib` | Delete or repurpose |
| `Spotiqueue/AppDelegate.swift` | New launch flow, connect OAuth to worker |
| `spotiqueue_worker.h` (generated) | Will update automatically via cbindgen |

---

## Order of Implementation

1. **Phase 1.1**: Upgrade SpotifyAPI package
2. **Phase 2**: Refactor Rust worker (can test independently with hardcoded token)
3. **Phase 1.2-1.3**: Add streaming scope, expose token
4. **Phase 3**: Refactor Swift UI and launch flow
5. **Phase 4**: Keychain cleanup
6. **Phase 5**: Testing
