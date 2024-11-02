use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::mpsc::{sync_channel, SyncSender};
use std::sync::Arc;
use std::thread;

use librespot::core::authentication::Credentials;
use librespot::core::config::SessionConfig;
use librespot::core::error::Error;
use librespot::core::session::Session;
use librespot::core::session::SessionError;
use librespot::core::spotify_id::SpotifyId;
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
        track: SpotifyId,
        start: bool,
        position_ms: u32,
    },
    Preload {
        track: SpotifyId,
    },
    Unpause,
}

impl New for State {
    fn new(player: Arc<Player>, _session: Session) -> State {
        let (tx, rx) = sync_channel(0);
        let state = State { send_channel: tx };
        let mut player_event_channel = player.get_player_event_channel();
        thread::spawn(move || loop {
            let cmd = rx.recv().unwrap();
            debug!("Command: {:?}", cmd);
            match cmd {
                Command::Pause => player.pause(),
                Command::Play {
                    track,
                    start,
                    position_ms,
                } => {
                    player.stop();
                    player.load(track, start, position_ms);
                }
                Command::Preload { track } => player.preload(track),
                Command::Unpause => {
                    player.play();
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
                    use_stored_callback(StatusUpdate::EndOfTrack, 0, 0);
                }
                PlayerEvent::Paused { position_ms, .. } => {
                    use_stored_callback(StatusUpdate::Paused, position_ms.into(), -1);
                }
                PlayerEvent::Playing { position_ms, .. } => {
                    use_stored_callback(StatusUpdate::Playing, position_ms.into(), -1);
                }
                PlayerEvent::Stopped { .. } => {
                    use_stored_callback(StatusUpdate::Stopped, 0, 0);
                }
                PlayerEvent::TimeToPreloadNextTrack { .. } => {
                    use_stored_callback(StatusUpdate::TimeToPreloadNextTrack, 0, 0);
                }
                PlayerEvent::AutoPlayChanged { .. } => {}
                PlayerEvent::FilterExplicitContentChanged { .. } => {}
                PlayerEvent::Loading { .. } => {}
                PlayerEvent::PlayRequestIdChanged { .. } => {}
                PlayerEvent::PositionCorrection { .. } => {}
                PlayerEvent::Preloading { .. } => {}
                PlayerEvent::RepeatChanged { .. } => {}
                PlayerEvent::Seeked { .. } => {}
                PlayerEvent::SessionClientChanged { .. } => {}
                PlayerEvent::SessionConnected { .. } => {}
                PlayerEvent::SessionDisconnected { .. } => {}
                PlayerEvent::ShuffleChanged { .. } => {}
                PlayerEvent::TrackChanged { audio_item, .. } => {
                    use_stored_callback(StatusUpdate::Playing, -1, audio_item.duration_ms.into());
                }
                PlayerEvent::Unavailable { .. } => {}
                PlayerEvent::VolumeChanged { .. } => {}
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
    pub callback: extern "C" fn(status: StatusUpdate, position_ms: i64, duration_ms: i64),
}

// https://stackoverflow.com/questions/50188710/rust-function-that-allocates-memory-and-calls-a-c-callback-crashes
#[no_mangle]
pub extern "C" fn set_callback(
    callback: extern "C" fn(status: StatusUpdate, position_ms: i64, duration_ms: i64),
) {
    CALLBACK.set(WorkerCallback { callback }).unwrap();
}

fn use_stored_callback(status: StatusUpdate, position_ms: i64, duration_ms: i64) {
    let cb = CALLBACK.get().unwrap();
    (cb.callback)(status, position_ms, duration_ms);
}

#[no_mangle]
pub extern "C" fn spotiqueue_initialize_worker() {
    Builder::new().filter_level(LevelFilter::Debug).init();
    if cfg!(debug_assertions) {
        println!("I am a DEBUG build.");
    } else {
        println!("I am a RELEASE build.");
    }

    RUNTIME.set(Runtime::new().unwrap()).unwrap();
}

#[no_mangle]
pub extern "C" fn spotiqueue_login_worker(
    username_raw: *const c_char,
    password_raw: *const c_char,
) -> InitializationResult {
    if username_raw.is_null() || password_raw.is_null() {
        let e = "Username or password not provided correctly.";
        return InitializationResult::InitProblem {
            description: string_from_rust(e),
        };
    }

    let username = c_str_to_rust_string(username_raw);
    let password = c_str_to_rust_string(password_raw);

    internal_login_worker(username, password)
}

fn internal_login_worker(username: String, password: String) -> InitializationResult {
    let session_config = SessionConfig::default();
    let player_config = PlayerConfig::default();
    let audio_format = AudioFormat::default();

    let credentials = Credentials::with_password(username, password);

    let backend = audio_backend::find(None).unwrap();

    info!("Authorizing...");

    let session = RUNTIME.get().unwrap().block_on(async {
        let inner_session = Session::new(session_config, None);
        if let Err(e) = inner_session.connect(credentials, false).await {
            // error connecting! handle it.
        }
        // otherwise, fine!
        return inner_session;
    });

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

#[no_mangle]
pub extern "C" fn spotiqueue_pause_playback() -> bool {
    let state = STATE.get().unwrap();
    state.send_command(Command::Pause);
    return true;
}

#[no_mangle]
pub extern "C" fn spotiqueue_unpause_playback() {
    let state = STATE.get().unwrap();
    state.send_command(Command::Unpause);
}

#[no_mangle]
pub extern "C" fn spotiqueue_preload_track(spotify_uri_raw: *const c_char) -> bool {
    let spotify_uri = c_str_to_rust_string(spotify_uri_raw);
    internal_preload_track(spotify_uri)
}

fn internal_preload_track(spotify_uri: String) -> bool {
    match track_id_from_spotify_uri(&spotify_uri) {
        Some(track) => {
            let state = STATE.get().unwrap();
            state.send_command(Command::Preload { track: track });
        }
        None => {
            error!("Looks like that isn't a Spotify track URI!");
            return false;
        }
    }
    return true;
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

    match track_id_from_spotify_uri(&spotify_uri) {
        Some(track) => {
            let state = STATE.get().unwrap();
            state.send_command(Command::Play {
                track: track,
                start: start,
                position_ms: position_ms,
            });
        }
        None => {
            error!("Looks like that isn't a Spotify track URI!");
            return false;
        }
    }
    return true;
}

fn track_id_from_spotify_uri(uri: &str) -> Option<SpotifyId> {
    // e.g., spotify:track:7lmeHLHBe4nmXzuXc0HDjk
    let components: Vec<&str> = uri.split(":").collect();

    if components.len() == 3 {
        if components[1] == "track" {
            let track_id = SpotifyId::from_base62(components[2]).unwrap();
            return Some(track_id);
        }
    }

    return None;
}
