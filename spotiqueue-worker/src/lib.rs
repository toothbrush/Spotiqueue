use std::ffi::CStr;
use std::os::raw::c_char;

use librespot::core::authentication::Credentials;
use librespot::core::config::SessionConfig;
use librespot::core::session::Session;
use librespot::core::spotify_id::SpotifyId;
use librespot::metadata::{Metadata, Track};
use librespot::playback::audio_backend;
use librespot::playback::config::{AudioFormat, PlayerConfig};
use librespot::playback::player::Player;

use lazy_static::lazy_static;
use std::sync::Mutex;

use tokio::runtime::Runtime;

lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().unwrap();
    static ref SESSION: Mutex<Option<Session>> = Mutex::new(None);
    static ref PLAYER: Mutex<Option<Player>> = Mutex::new(None);
}

fn c_str_to_rust_string(s_raw: *const c_char) -> &'static str {
    if s_raw.is_null() {
        println!("Null string!");
        return "";
    }
    // take string from the input C string
    let c_str: &CStr = unsafe { CStr::from_ptr(s_raw) };
    let buf: &[u8] = c_str.to_bytes();
    let str_slice: &str = std::str::from_utf8(buf).unwrap();
    // let str_buf: String = str_slice.to_owned();
    // return str_buf;
    return str_slice;
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn spotiqueue_initialize_worker(
    username_raw: *const c_char,
    password_raw: *const c_char,
) -> bool {
    let session_config = SessionConfig::default();
    let player_config = PlayerConfig::default();
    let audio_format = AudioFormat::default();

    if username_raw.is_null() || password_raw.is_null() {
        println!("Username or password not provided correctly.");
        return false;
    }

    let username = c_str_to_rust_string(username_raw);
    let password = c_str_to_rust_string(password_raw);

    let credentials = Credentials::with_password(username, password);

    let backend = audio_backend::find(None).unwrap();

    println!("credentials: {:?} and {:?}", username, password);
    println!("Authorizing...");

    let session: Session = RUNTIME.block_on(async {
        Session::connect(session_config, credentials, None)
            .await
            .unwrap()
    });
    {
        let mut sess = SESSION.lock().unwrap();
        *sess = Some(session);
    }

    println!("Authorized.");

    return true;
}

#[allow(dead_code)]
#[no_mangle]
pub extern "C" fn spotiqueue_play_track(spotify_uri_raw: *const c_char) -> bool {
    let spotify_uri = c_str_to_rust_string(spotify_uri_raw);
    println!("Will play {}...", spotify_uri);

    match track_id_from_spotify_uri(spotify_uri) {
        Some(track) => {
            let player_config = PlayerConfig::default();
            let audio_format = AudioFormat::default();
            let backend = audio_backend::find(None).unwrap();
            let session: Session = SESSION.lock().unwrap().as_ref().unwrap().clone();
            let (mut player, _) = Player::new(player_config, session, None, move || {
                backend(None, audio_format)
            });

            player.load(track, true, 0);

            // let sth = PLAYER.lock().unwrap();
            // let mut player = sth.as_ref().unwrap();
            // player.load(track, true, 0);
            // &mut PLAYER
            //     .lock()
            //     .expect("lock was poisoned")
            //     .as_ref()
            //     .unwrap()
            //     .load(track, true, 0);
        }
        None => {
            println!("Looks like that isn't a Spotify track URI!");
            return false;
        }
    }
    println!("Playing.");

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
