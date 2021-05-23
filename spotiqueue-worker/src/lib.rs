use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::mpsc::sync_channel;
use std::sync::mpsc::SyncSender;
use std::thread;

use librespot::core::authentication::Credentials;
use librespot::core::config::SessionConfig;
use librespot::core::session::Session;
use librespot::core::spotify_id::SpotifyId;
use librespot::playback::audio_backend;
use librespot::playback::config::{AudioFormat, PlayerConfig};
use librespot::playback::player::Player;

use once_cell::sync::OnceCell;

use tokio::runtime::Runtime;

static RUNTIME: OnceCell<Runtime> = OnceCell::new();
static STATE: OnceCell<State> = OnceCell::new();

trait New {
    fn new(player: Player, session: Session) -> Self;
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
    Play { track: SpotifyId },
}

impl New for State {
    fn new(mut player: Player, _session: Session) -> State {
        let (tx, rx) = sync_channel(0);
        let state = State { send_channel: tx };
        thread::spawn(move || loop {
            let cmd = rx.recv().unwrap();
            println!("Command: {:?}", cmd);
            match cmd {
                Command::Pause => player.pause(),
                Command::Play { track } => {
                    player.stop();
                    player.load(track, true, 0);
                }
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
        println!("Null string!");
        return "".to_owned();
    }
    // take string from the input C string
    let c_str: &CStr = unsafe { CStr::from_ptr(s_raw) };
    let buf: &[u8] = c_str.to_bytes();
    let str_slice: &str = std::str::from_utf8(buf).unwrap();
    let str_buf: String = str_slice.to_owned();
    return str_buf;
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn spotiqueue_initialize_worker(
    username_raw: *const c_char,
    password_raw: *const c_char,
) -> bool {
    RUNTIME.set(Runtime::new().unwrap()).unwrap();

    if username_raw.is_null() || password_raw.is_null() {
        println!("Username or password not provided correctly.");
        return false;
    }

    let session_config = SessionConfig::default();
    let player_config = PlayerConfig::default();
    let audio_format = AudioFormat::default();

    let username = c_str_to_rust_string(username_raw);
    let password = c_str_to_rust_string(password_raw);

    let credentials = Credentials::with_password(username.clone(), password.clone());

    let backend = audio_backend::find(None).unwrap();

    println!("Authorizing...");

    let session: Session = RUNTIME.get().unwrap().block_on(async {
        Session::connect(session_config, credentials, None)
            .await
            .unwrap()
    });

    let (player, _) = Player::new(player_config, session.clone(), None, move || {
        backend(None, audio_format)
    });
    STATE.set(State::new(player, session)).unwrap();

    println!("Authorized.");

    return true;
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn spotiqueue_pause_playback() -> bool {
    let state = STATE.get().unwrap().clone();
    state.send_command(Command::Pause);
    return true;
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn spotiqueue_play_track(spotify_uri_raw: *const c_char) -> bool {
    let spotify_uri = c_str_to_rust_string(spotify_uri_raw);
    println!("Trying to play {}...", spotify_uri);

    match track_id_from_spotify_uri(&spotify_uri) {
        Some(track) => {
            let state = STATE.get().unwrap().clone();
            state.send_command(Command::Play { track: track });
        }
        None => {
            println!("Looks like that isn't a Spotify track URI!");
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
