use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::mpsc::{sync_channel, SyncSender};
use std::sync::Arc;
use std::thread;

use librespot::core::authentication::Credentials;
use librespot::core::config::SessionConfig;
use librespot::core::session::Session;
use librespot::core::spotify_uri::SpotifyUri;
use librespot::core::Error;
use librespot::playback::audio_backend;
use librespot::playback::config::{AudioFormat, PlayerConfig};
use librespot::playback::mixer::NoOpVolume;
use librespot::playback::player::{Player, PlayerEvent};

use once_cell::sync::OnceCell;

use tokio::runtime::Runtime;

use env_logger::Builder;
use log::LevelFilter;
use log::{debug, error, info};

#[allow(dead_code)]
static RUNTIME: OnceCell<Runtime> = OnceCell::new();
static STATE: OnceCell<State> = OnceCell::new();
static CALLBACK: OnceCell<WorkerCallback> = OnceCell::new();

trait New {
    fn new(player: Arc<Player>, session: Session) -> Self;
}

trait SendCommand {
    fn send_command(&self, command: Command);
}

#[derive(Debug)]
struct State {
    send_channel: SyncSender<Command>,
}

#[derive(Debug)]
enum Command {
    Pause,
    Play {
        track: SpotifyUri,
        start: bool,
        position_ms: u32,
    },
    Preload {
        track: SpotifyUri,
    },
    Unpause,
}

impl New for State {
    fn new(player: Arc<Player>, _session: Session) -> State {
        let (tx, rx) = sync_channel(0);
        let state = State { send_channel: tx };
        let mut player_event_channel = player.get_player_event_channel();
        let player_clone = player.clone();
        thread::spawn(move || loop {
            let cmd = rx.recv().unwrap();
            debug!("Command: {:?}", cmd);
            match cmd {
                Command::Pause => player_clone.pause(),
                Command::Play {
                    track,
                    start,
                    position_ms,
                } => {
                    player_clone.stop();
                    player_clone.load(track, start, position_ms);
                }
                Command::Preload { track } => player_clone.preload(track),
                Command::Unpause => {
                    player_clone.play();
                }
            }
        });
        info!("Spawning the player-event listening thread");
        thread::spawn(move || loop {
            let event: PlayerEvent = RUNTIME
                .get()
                .unwrap()
                .block_on(async { player_event_channel.recv().await.unwrap() });
            info!("PlayerEvent ==> {:?}", event);
            match event {
                PlayerEvent::EndOfTrack { .. } => {
                    use_stored_callback(StatusUpdate::EndOfTrack, 0);
                }
                PlayerEvent::Paused { position_ms, .. } => {
                    use_stored_callback(StatusUpdate::Paused, position_ms);
                }
                PlayerEvent::Playing { position_ms, .. } => {
                    use_stored_callback(StatusUpdate::Playing, position_ms);
                }
                PlayerEvent::Stopped { .. } => {
                    use_stored_callback(StatusUpdate::Stopped, 0);
                }
                PlayerEvent::TimeToPreloadNextTrack { .. } => {
                    use_stored_callback(StatusUpdate::TimeToPreloadNextTrack, 0);
                }
                // All other events we don't need to handle
                _ => {}
            }
        });
        return state;
    }
}

impl SendCommand for State {
    fn send_command(&self, command: Command) {
        self.send_channel.send(command).unwrap();
    }
}

fn c_str_to_rust_string(s_raw: *const c_char) -> String {
    if s_raw.is_null() {
        panic!("Null string!");
    }
    // take string from the input C string
    let c_str: &CStr = unsafe { CStr::from_ptr(s_raw) };
    let buf: &[u8] = c_str.to_bytes();
    let str_slice: &str = std::str::from_utf8(buf).unwrap();
    let str_buf: String = str_slice.to_owned();
    return str_buf;
}

#[repr(C)]
#[derive(Debug)]
pub enum StatusUpdate {
    EndOfTrack,
    Paused,
    Playing,
    Stopped,
    TimeToPreloadNextTrack,
}

#[repr(C)]
#[derive(Debug)]
pub enum InitializationResult {
    InitOkay,
    InitBadCredentials,
    InitNotPremium,
    // A catch-all "other" error with space for a string to explain:
    InitProblem { description: *const c_char },
}

// https://thefullsnack.com/en/string-ffi-rust.html
fn string_from_rust(string: &str) -> *const c_char {
    let s = CString::new(string).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s);
    p
}

#[derive(Debug)]
pub struct WorkerCallback {
    pub callback: extern "C" fn(status: StatusUpdate, position_ms: u32),
}

// https://stackoverflow.com/questions/50188710/rust-function-that-allocates-memory-and-calls-a-c-callback-crashes
#[no_mangle]
pub extern "C" fn set_callback(callback: extern "C" fn(status: StatusUpdate, position_ms: u32)) {
    CALLBACK.set(WorkerCallback { callback }).unwrap();
}

fn use_stored_callback(status: StatusUpdate, position_ms: u32) {
    let cb = CALLBACK.get().unwrap();
    (cb.callback)(status, position_ms);
}

#[no_mangle]
pub extern "C" fn spotiqueue_initialize_worker() {
    // Use try_init to avoid panic if logger already initialized
    let _ = Builder::new().filter_level(LevelFilter::Debug).try_init();
    if cfg!(debug_assertions) {
        println!("I am a DEBUG build.");
    } else {
        println!("I am a RELEASE build.");
    }

    // Use get_or_init to avoid panic if runtime already set
    let _ = RUNTIME.set(Runtime::new().unwrap());
}

/// Login with OAuth access token (new API for librespot 0.8+)
#[no_mangle]
pub extern "C" fn spotiqueue_login_worker(access_token_raw: *const c_char) -> InitializationResult {
    if access_token_raw.is_null() {
        let e = "Access token not provided.";
        return InitializationResult::InitProblem {
            description: string_from_rust(e),
        };
    }

    let access_token = c_str_to_rust_string(access_token_raw);
    internal_login_worker(access_token)
}

fn internal_login_worker(access_token: String) -> InitializationResult {
    let session_config = SessionConfig::default();
    let player_config = PlayerConfig::default();
    let audio_format = AudioFormat::default();

    // Use OAuth access token for authentication
    let credentials = Credentials::with_access_token(access_token);

    let backend = audio_backend::find(None).unwrap();

    info!("Authorizing with OAuth token...");

    // Session::new and connect must both be called within the Tokio runtime context
    let connect_result = RUNTIME.get().unwrap().block_on(async {
        let session = Session::new(session_config, None);
        match session.connect(credentials, false).await {
            Ok(()) => Ok(session),
            Err(e) => Err(e),
        }
    });

    let session = match connect_result {
        Ok(session) => {
            info!("Session connected successfully.");
            session
        }
        Err(err) => {
            return handle_connection_error(err);
        }
    };

    // Create player with the new API
    let player = Player::new(
        player_config,
        session.clone(),
        Box::new(NoOpVolume),
        move || backend(None, audio_format),
    );

    STATE.set(State::new(player, session)).unwrap();

    info!("Authorized.");

    return InitializationResult::InitOkay;
}

fn handle_connection_error(err: Error) -> InitializationResult {
    use librespot::core::error::ErrorKind;

    let e: String = format!("spotiqueue_worker: Connection error: {}", err);
    error!("{}", e);

    // Righto, this is fairly horrific.  The librespot library doesn't let us directly import the
    // enum contained in AuthenticationError, LoginFailed.  They only seem to let use their prefab
    // error strings, see
    // https://github.com/librespot-org/librespot/blob/041f084d7f5f3e0731b712064f61105b509e5154/core/src/connection/mod.rs#L24-L39.
    //
    // Anyway, this is good enough, for now - we just want to be able to give the user a
    // reasonable error message if it turns out they try to use a free account.  I need
    // to go take a shower.  It might well be that i just don't understand Rust well
    // enough to actually be able to get ahold of the true error codes, but oh well!
    match err.kind {
        ErrorKind::Unauthenticated => {
            // Check if it's a credentials issue
            let error_str = format!("{:?}", err);
            if error_str.contains("BadCredentials") {
                return InitializationResult::InitBadCredentials;
            } else if error_str.contains("PremiumAccountRequired") {
                return InitializationResult::InitNotPremium;
            }
            return InitializationResult::InitBadCredentials;
        }
        ErrorKind::PermissionDenied => {
            // Likely a premium account issue
            let error_str = format!("{:?}", err);
            if error_str.contains("PremiumAccountRequired") {
                return InitializationResult::InitNotPremium;
            }
            return InitializationResult::InitProblem {
                description: string_from_rust(&e),
            };
        }
        _ => {
            return InitializationResult::InitProblem {
                description: string_from_rust(&e),
            };
        }
    }
}

#[no_mangle]
pub extern "C" fn spotiqueue_pause_playback() -> bool {
    match STATE.get() {
        Some(state) => {
            state.send_command(Command::Pause);
            true
        }
        None => {
            error!("Cannot pause: worker not initialized");
            false
        }
    }
}

#[no_mangle]
pub extern "C" fn spotiqueue_unpause_playback() -> bool {
    match STATE.get() {
        Some(state) => {
            state.send_command(Command::Unpause);
            true
        }
        None => {
            error!("Cannot unpause: worker not initialized");
            false
        }
    }
}

#[no_mangle]
pub extern "C" fn spotiqueue_preload_track(spotify_uri_raw: *const c_char) -> bool {
    let spotify_uri = c_str_to_rust_string(spotify_uri_raw);
    internal_preload_track(spotify_uri)
}

fn internal_preload_track(spotify_uri: String) -> bool {
    let state = match STATE.get() {
        Some(s) => s,
        None => {
            error!("Cannot preload: worker not initialized");
            return false;
        }
    };

    match track_uri_from_spotify_uri(&spotify_uri) {
        Some(track) => {
            state.send_command(Command::Preload { track: track });
            true
        }
        None => {
            error!("Looks like that isn't a Spotify track URI!");
            false
        }
    }
}

#[no_mangle]
pub extern "C" fn spotiqueue_play_track(
    spotify_uri_raw: *const c_char,
    start: bool,
    position_ms: u32,
) -> bool {
    let spotify_uri = c_str_to_rust_string(spotify_uri_raw);
    internal_play_track(spotify_uri, start, position_ms)
}

fn internal_play_track(spotify_uri: String, start: bool, position_ms: u32) -> bool {
    info!("Trying to play {}...", spotify_uri);

    let state = match STATE.get() {
        Some(s) => s,
        None => {
            error!("Cannot play: worker not initialized");
            return false;
        }
    };

    match track_uri_from_spotify_uri(&spotify_uri) {
        Some(track) => {
            state.send_command(Command::Play {
                track: track,
                start: start,
                position_ms: position_ms,
            });
            true
        }
        None => {
            error!("Looks like that isn't a Spotify track URI!");
            false
        }
    }
}

fn track_uri_from_spotify_uri(uri: &str) -> Option<SpotifyUri> {
    // e.g., spotify:track:7lmeHLHBe4nmXzuXc0HDjk
    // Use the new SpotifyUri::from_uri parser
    match SpotifyUri::from_uri(uri) {
        Ok(spotify_uri) => {
            // Only accept track URIs for playback
            match &spotify_uri {
                SpotifyUri::Track { .. } => Some(spotify_uri),
                _ => {
                    error!("URI is not a track: {}", uri);
                    None
                }
            }
        }
        Err(e) => {
            error!("Failed to parse Spotify URI '{}': {}", uri, e);
            None
        }
    }
}
