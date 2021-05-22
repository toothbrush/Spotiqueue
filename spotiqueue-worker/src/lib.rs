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
use std::sync::RwLock;

use async_std::task;
use tokio::runtime::Runtime;

lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().unwrap();
    static ref SESSION: RwLock<Option<Session>> = RwLock::new(None);
    static ref PLAYER: Mutex<Option<Player>> = Mutex::new(None);
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
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

    // let track_id = SpotifyId::from_base62(&args[3]).unwrap();

    let backend = audio_backend::find(None).unwrap();

    println!("credentials: {:?} and {:?}", username, password);
    println!("Authorizing...");

    let session: Session = RUNTIME.block_on(async {
        Session::connect(session_config, credentials, None)
            .await
            .unwrap()
    });
    {
        let mut sess = SESSION.write().unwrap();
        *sess = Some(session);
    }

    println!("Authorized.");

    let (player, _) = Player::new(
        player_config,
        SESSION.read().unwrap().as_ref().unwrap().clone(),
        None,
        move || backend(None, audio_format),
    );
    {
        let mut play = PLAYER.lock().unwrap();
        *play = Some(player);
    }

    return true;
}
