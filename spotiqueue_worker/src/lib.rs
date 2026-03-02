use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::io::Cursor;
use std::os::raw::c_char;
use std::sync::mpsc::{sync_channel, SyncSender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use once_cell::sync::OnceCell;

use tokio::runtime::Runtime;

use env_logger::Builder;
use log::LevelFilter;
use log::{debug, error, info, warn};

use rodio::{Decoder, OutputStream, Sink};

use tidalrs::{AudioQuality, Authz, TidalClient};

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

static RUNTIME: OnceCell<Runtime> = OnceCell::new();
static STATE: OnceCell<State> = OnceCell::new();
static CALLBACK: OnceCell<WorkerCallback> = OnceCell::new();

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

#[repr(C)]
#[derive(Debug, strum::IntoStaticStr)]
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

#[derive(Debug)]
pub struct WorkerCallback {
    pub callback: extern "C" fn(status: StatusUpdate, position_ms: u32),
}

// ---------------------------------------------------------------------------
// Commands sent to the playback thread
// ---------------------------------------------------------------------------

#[derive(Debug)]
enum Command {
    Pause,
    Play {
        track_id: u64,
        start: bool,
        position_ms: u32,
    },
    Preload {
        track_id: u64,
    },
    Unpause,
}

// ---------------------------------------------------------------------------
// Playback state shared between command thread and event-polling thread
// ---------------------------------------------------------------------------

struct PlaybackInfo {
    /// rodio Sink for the current track (None when nothing loaded).
    sink: Option<Sink>,
    /// Whether playback is paused.
    paused: bool,
    /// When playback started (wall-clock), adjusted on unpause.
    play_start: Option<Instant>,
    /// Accumulated position in ms before the most recent pause.
    accumulated_ms: u32,
    /// Total track duration in ms (if known from the stream metadata).
    track_duration_ms: Option<u64>,
    /// Whether we already fired TimeToPreloadNextTrack for this track.
    preload_fired: bool,
}

impl PlaybackInfo {
    fn new() -> Self {
        PlaybackInfo {
            sink: None,
            paused: false,
            play_start: None,
            accumulated_ms: 0,
            track_duration_ms: None,
            preload_fired: false,
        }
    }

    fn current_position_ms(&self) -> u32 {
        let elapsed = match (self.paused, self.play_start) {
            (false, Some(t)) => t.elapsed().as_millis() as u32,
            _ => 0,
        };
        self.accumulated_ms + elapsed
    }
}

// ---------------------------------------------------------------------------
// State — owns the Tidal client and the command channel
// ---------------------------------------------------------------------------

struct State {
    send_channel: SyncSender<Command>,
}

impl State {
    fn send_command(&self, command: Command) {
        if let Err(e) = self.send_channel.send(command) {
            error!("Failed to send command: {}", e);
        }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn c_str_to_rust_string(s_raw: *const c_char) -> String {
    if s_raw.is_null() {
        panic!("Null string!");
    }
    let c_str: &CStr = unsafe { CStr::from_ptr(s_raw) };
    let buf: &[u8] = c_str.to_bytes();
    let str_slice: &str = std::str::from_utf8(buf).unwrap();
    str_slice.to_owned()
}

// https://thefullsnack.com/en/string-ffi-rust.html
fn string_from_rust(string: &str) -> *const c_char {
    let s = CString::new(string).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s);
    p
}

fn use_stored_callback(status: StatusUpdate, position_ms: u32) {
    if let Some(cb) = CALLBACK.get() {
        (cb.callback)(status, position_ms);
    }
}

fn parse_track_id(s: &str) -> Option<u64> {
    s.trim().parse::<u64>().ok()
}

/// Fetch audio bytes for a Tidal track.  Returns the raw bytes (e.g. FLAC).
fn fetch_track_audio(client: &TidalClient, track_id: u64) -> Result<Vec<u8>, String> {
    let rt = RUNTIME.get().ok_or("Runtime not initialized")?;

    rt.block_on(async {
        // Get the stream URL from Tidal
        let stream = client
            .track_stream(track_id, AudioQuality::Lossless)
            .await
            .map_err(|e| format!("Failed to get track stream: {}", e))?;

        let url = stream.urls.first().ok_or("No stream URLs returned")?;

        // Fetch the actual audio bytes from the URL
        let bytes = reqwest::get(url)
            .await
            .map_err(|e| format!("Failed to fetch audio: {}", e))?
            .bytes()
            .await
            .map_err(|e| format!("Failed to read audio bytes: {}", e))?;

        Ok(bytes.to_vec())
    })
}

// ---------------------------------------------------------------------------
// FFI entry points
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn status_update_name(status: StatusUpdate) -> *const c_char {
    match status {
        StatusUpdate::EndOfTrack => c"EndOfTrack",
        StatusUpdate::Paused => c"Paused",
        StatusUpdate::Playing => c"Playing",
        StatusUpdate::Stopped => c"Stopped",
        StatusUpdate::TimeToPreloadNextTrack => c"TimeToPreloadNextTrack",
    }
    .as_ptr()
}

#[no_mangle]
pub extern "C" fn set_callback(callback: extern "C" fn(status: StatusUpdate, position_ms: u32)) {
    CALLBACK.set(WorkerCallback { callback }).unwrap();
}

#[no_mangle]
pub extern "C" fn spotiqueue_initialize_worker() {
    let _ = Builder::new().filter_level(LevelFilter::Debug).try_init();
    if cfg!(debug_assertions) {
        println!("I am a DEBUG build.");
    } else {
        println!("I am a RELEASE build.");
    }
    let _ = RUNTIME.set(Runtime::new().unwrap());
}

/// Login with Tidal OAuth tokens.
/// Swift handles the device-flow UI and passes the resulting tokens here.
///
/// - `client_id`: Tidal API client ID
/// - `access_token`, `refresh_token`: OAuth tokens from the device-flow
/// - `user_id`: Tidal user ID
#[no_mangle]
pub extern "C" fn spotiqueue_login_worker(
    client_id_raw: *const c_char,
    access_token_raw: *const c_char,
    refresh_token_raw: *const c_char,
    user_id: u64,
) -> InitializationResult {
    if client_id_raw.is_null() || access_token_raw.is_null() || refresh_token_raw.is_null() {
        let e = "client_id, access_token, or refresh_token not provided.";
        return InitializationResult::InitProblem {
            description: string_from_rust(e),
        };
    }

    let client_id = c_str_to_rust_string(client_id_raw);
    let access_token = c_str_to_rust_string(access_token_raw);
    let refresh_token = c_str_to_rust_string(refresh_token_raw);
    internal_login_worker(client_id, access_token, refresh_token, user_id)
}

fn internal_login_worker(
    client_id: String,
    access_token: String,
    refresh_token: String,
    user_id: u64,
) -> InitializationResult {
    info!("Authorizing with Tidal OAuth tokens...");

    let authz = Authz::new(access_token, refresh_token, user_id, None);

    let client = TidalClient::new(client_id).with_authz(authz);

    // Set up the audio output — keep the stream handle alive for the app's lifetime.
    let client = Arc::new(client);
    let playback = Arc::new(Mutex::new(PlaybackInfo::new()));
    let preload_cache: Arc<Mutex<HashMap<u64, Vec<u8>>>> = Arc::new(Mutex::new(HashMap::new()));

    let (tx, rx) = sync_channel::<Command>(8);

    // ------- Command thread -------
    // OutputStream is !Send, so it must be created inside the thread that uses it.
    let cmd_client = Arc::clone(&client);
    let cmd_playback = Arc::clone(&playback);
    let cmd_cache = Arc::clone(&preload_cache);

    thread::spawn(move || {
        // Create audio output on this thread — OutputStream is !Send.
        let (_stream, stream_handle) = match OutputStream::try_default() {
            Ok(pair) => pair,
            Err(e) => {
                error!("Failed to open audio output: {}", e);
                return;
            }
        };

        loop {
            let cmd = match rx.recv() {
                Ok(c) => c,
                Err(_) => {
                    info!("Command channel closed, exiting command thread.");
                    break;
                }
            };
            debug!("Command: {:?}", cmd);

            match cmd {
                Command::Pause => {
                    let mut pb = cmd_playback.lock().unwrap();
                    if let Some(ref sink) = pb.sink {
                        sink.pause();
                    }
                    // Accumulate elapsed time
                    if let Some(t) = pb.play_start.take() {
                        pb.accumulated_ms += t.elapsed().as_millis() as u32;
                    }
                    pb.paused = true;
                    let pos = pb.current_position_ms();
                    drop(pb);
                    use_stored_callback(StatusUpdate::Paused, pos);
                }

                Command::Unpause => {
                    let mut pb = cmd_playback.lock().unwrap();
                    if let Some(ref sink) = pb.sink {
                        sink.play();
                    }
                    pb.play_start = Some(Instant::now());
                    pb.paused = false;
                    let pos = pb.current_position_ms();
                    drop(pb);
                    use_stored_callback(StatusUpdate::Playing, pos);
                }

                Command::Preload { track_id } => {
                    info!("Preloading track {}...", track_id);
                    match fetch_track_audio(&cmd_client, track_id) {
                        Ok(bytes) => {
                            cmd_cache.lock().unwrap().insert(track_id, bytes);
                            info!("Preloaded track {} successfully.", track_id);
                        }
                        Err(e) => {
                            error!("Failed to preload track {}: {}", track_id, e);
                        }
                    }
                }

                Command::Play {
                    track_id,
                    start,
                    position_ms,
                } => {
                    info!("Playing track {} (start={}, pos={}ms)...", track_id, start, position_ms);

                    // Stop current playback if any
                    {
                        let mut pb = cmd_playback.lock().unwrap();
                        if let Some(old_sink) = pb.sink.take() {
                            old_sink.stop();
                        }
                    }

                    use_stored_callback(StatusUpdate::Stopped, 0);

                    // Get audio bytes — from cache or fetch
                    let audio_bytes = {
                        let mut cache = cmd_cache.lock().unwrap();
                        cache.remove(&track_id)
                    };
                    let audio_bytes = match audio_bytes {
                        Some(b) => {
                            info!("Using preloaded audio for track {}.", track_id);
                            b
                        }
                        None => match fetch_track_audio(&cmd_client, track_id) {
                            Ok(b) => b,
                            Err(e) => {
                                error!("Failed to fetch track {}: {}", track_id, e);
                                continue;
                            }
                        },
                    };

                    // Decode and play via rodio
                    let cursor = Cursor::new(audio_bytes);
                    let source = match Decoder::new(cursor) {
                        Ok(s) => s,
                        Err(e) => {
                            error!("Failed to decode audio for track {}: {}", track_id, e);
                            continue;
                        }
                    };

                    let sink = match Sink::try_new(&stream_handle) {
                        Ok(s) => s,
                        Err(e) => {
                            error!("Failed to create audio sink: {}", e);
                            continue;
                        }
                    };

                    sink.append(source);

                    if !start {
                        sink.pause();
                    }

                    // TODO: if position_ms > 0, we'd need to seek — rodio doesn't
                    // support seeking easily on Decoder.  For now we start from 0.
                    if position_ms > 0 {
                        warn!("Seeking to {}ms not yet implemented, starting from beginning.", position_ms);
                    }

                    let mut pb = cmd_playback.lock().unwrap();
                    pb.sink = Some(sink);
                    pb.paused = !start;
                    pb.accumulated_ms = position_ms;
                    pb.play_start = if start { Some(Instant::now()) } else { None };
                    pb.track_duration_ms = None; // TODO: get from Tidal metadata
                    pb.preload_fired = false;
                    let pos = pb.current_position_ms();
                    drop(pb);

                    if start {
                        use_stored_callback(StatusUpdate::Playing, pos);
                    }
                }
            }
        }
    });

    // ------- Event polling thread -------
    let evt_playback = Arc::clone(&playback);

    thread::spawn(move || {
        let poll_interval = Duration::from_millis(250);
        let mut was_empty = true;
        let mut had_sink = false;

        loop {
            thread::sleep(poll_interval);

            let pb = evt_playback.lock().unwrap();
            let has_sink = pb.sink.is_some();
            let is_paused = pb.paused;

            if let Some(ref sink) = pb.sink {
                let empty = sink.empty();
                let pos = pb.current_position_ms();
                let duration = pb.track_duration_ms;
                let preload_fired = pb.preload_fired;
                drop(pb);

                // Fire position update while playing
                if !is_paused && !empty {
                    use_stored_callback(StatusUpdate::Playing, pos);
                }

                // Detect end-of-track: sink was non-empty, now empty
                if empty && !was_empty && had_sink {
                    info!("End of track detected at {}ms.", pos);
                    use_stored_callback(StatusUpdate::EndOfTrack, 0);
                }

                // Fire TimeToPreloadNextTrack at ~90% through
                if !preload_fired {
                    if let Some(dur) = duration {
                        if dur > 0 && (pos as u64) >= dur * 90 / 100 {
                            info!("Time to preload next track (at {}ms of {}ms).", pos, dur);
                            evt_playback.lock().unwrap().preload_fired = true;
                            use_stored_callback(StatusUpdate::TimeToPreloadNextTrack, 0);
                        }
                    } else {
                        // No duration info — fire preload based on time-remaining heuristic.
                        // If sink reports empty soon, the EndOfTrack path handles it.
                        // As a fallback, fire preload after 30 seconds of playback.
                        if pos > 30_000 && !is_paused {
                            // Only fire once
                            evt_playback.lock().unwrap().preload_fired = true;
                            use_stored_callback(StatusUpdate::TimeToPreloadNextTrack, 0);
                        }
                    }
                }

                was_empty = empty;
            } else {
                drop(pb);
                was_empty = true;
            }

            had_sink = has_sink;
        }
    });

    STATE
        .set(State { send_channel: tx })
        .map_err(|_| "STATE already set")
        .unwrap();

    info!("Authorized with Tidal.");
    InitializationResult::InitOkay
}

// ---------------------------------------------------------------------------
// Pause / Unpause
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Play / Preload
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn spotiqueue_play_track(
    track_id_raw: *const c_char,
    start: bool,
    position_ms: u32,
) -> bool {
    let track_id_str = c_str_to_rust_string(track_id_raw);
    internal_play_track(track_id_str, start, position_ms)
}

fn internal_play_track(track_id_str: String, start: bool, position_ms: u32) -> bool {
    info!("Trying to play track {}...", track_id_str);

    let state = match STATE.get() {
        Some(s) => s,
        None => {
            error!("Cannot play: worker not initialized");
            return false;
        }
    };

    match parse_track_id(&track_id_str) {
        Some(track_id) => {
            state.send_command(Command::Play {
                track_id,
                start,
                position_ms,
            });
            true
        }
        None => {
            error!("Invalid Tidal track ID: '{}'", track_id_str);
            false
        }
    }
}

#[no_mangle]
pub extern "C" fn spotiqueue_preload_track(track_id_raw: *const c_char) -> bool {
    let track_id_str = c_str_to_rust_string(track_id_raw);
    internal_preload_track(track_id_str)
}

fn internal_preload_track(track_id_str: String) -> bool {
    let state = match STATE.get() {
        Some(s) => s,
        None => {
            error!("Cannot preload: worker not initialized");
            return false;
        }
    };

    match parse_track_id(&track_id_str) {
        Some(track_id) => {
            state.send_command(Command::Preload { track_id });
            true
        }
        None => {
            error!("Invalid Tidal track ID: '{}'", track_id_str);
            false
        }
    }
}
