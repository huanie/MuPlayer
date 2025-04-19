pub mod database;
pub mod types;
pub use database::error;
use lofty::file::TaggedFileExt;
use r2d2_sqlite::rusqlite::OpenFlags;
use std::path::Path;
use types::SqlitePool;

/// Gives you a SQLite database from `path`.
///
/// It will initialize the schema if `path` did not exist.
///
/// Error can only be some FileIO error or an underlying SQLite error
fn database<P: AsRef<Path>>(path: P) -> Result<SqlitePool, std::io::Error> {
    let path = path.as_ref();
    let manager = if !path.exists() {
        std::fs::create_dir_all(path.parent().ok_or(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Do not pass a directory!",
        ))?)?;
        r2d2_sqlite::SqliteConnectionManager::file(path)
            .with_flags(
                OpenFlags::SQLITE_OPEN_NO_MUTEX
                    | OpenFlags::SQLITE_OPEN_CREATE
                    | OpenFlags::SQLITE_OPEN_READ_WRITE,
            )
            .with_init(|x| x.execute_batch(include_str!("./schema.sql")))
    } else {
        r2d2_sqlite::SqliteConnectionManager::file(path)
            .with_flags(OpenFlags::SQLITE_OPEN_NO_MUTEX | OpenFlags::SQLITE_OPEN_READ_WRITE)
    };
    Ok(r2d2::Builder::new()
        .min_idle(Some(1))
        .build_unchecked(manager))
}

/// Return the cover image of the passed file
pub fn cover_data<P: AsRef<Path>>(path: P) -> Result<Vec<u8>, database::error::ScanError> {
    use database::error::ScanError::NoCover;
    let path = lofty::probe::read_from_path(path)?;
    Ok(path
        .primary_tag()
        .ok_or(NoCover)?
        .pictures()
        .first()
        .ok_or(NoCover)?
        .data()
        .to_owned())
}

pub mod c_api {
    use crate::database;
    use std::ffi;

    macro_rules! err {
        ($ex:expr) => {
            match $ex {
                Ok(x) => x,
                Err(_) => return -1,
            }
        };
    }
    /// # Safety
    /// C API
    /// Return NULL on error, the Vec on success
    #[no_mangle]
    pub unsafe extern "C" fn album_cover_get(
        file: *const ffi::c_char,
        length: *mut usize,
    ) -> *mut u8 {
        macro_rules! err {
            ($ex:expr) => {
                match $ex {
                    Ok(x) => x,
                    Err(_) => return std::ptr::null_mut(),
                }
            };
        }
        let file = unsafe { ffi::CStr::from_ptr(file).to_str() };
        let data = super::cover_data(err!(file));
        let mut data = err!(data);
        data.shrink_to_fit();
        *length = data.len();
        std::mem::ManuallyDrop::new(data).as_mut_ptr()
    }

    /// # Safety
    /// Free the Rust Vec
    #[no_mangle]
    pub unsafe extern "C" fn album_cover_free(vec: *mut u8, length: usize) {
        drop(Vec::from_raw_parts(vec, length, length))
    }

    /// Return 0 on success
    /// # Safety
    /// This is a C API
    #[no_mangle]
    pub unsafe extern "C" fn scan_directory(
        scan_directory: *const ffi::c_char,
        database_file: *const ffi::c_char,
    ) -> i32 {
        let scan_directory = unsafe { ffi::CStr::from_ptr(scan_directory).to_str() };
        let database_file = unsafe { ffi::CStr::from_ptr(database_file).to_str() };
        !database::scan_directory(err!(scan_directory), err!(database(err!(database_file))))
            .1
            .is_empty() as i32
    }

    /// Return 0 on success
    /// # Safety
    /// This is a C API
    #[no_mangle]
    pub unsafe extern "C" fn rescan_directory(
        scan_directory: *const ffi::c_char,
        database_file: *const ffi::c_char,
    ) -> i32 {
        let scan_directory = unsafe { ffi::CStr::from_ptr(scan_directory).to_str() };
        let database_file = unsafe { ffi::CStr::from_ptr(database_file).to_str() };
        !database::rescan_directory(err!(scan_directory), err!(database(err!(database_file))))
            .1
            .is_empty() as i32
    }
    // #[derive(Clone)]
    // #[repr(C)]
    // pub struct Ptr(*mut ffi::c_void);
    // unsafe impl Send for Ptr {}

    // /// # Safety
    // /// This is a C API
    // #[no_mangle]
    // pub unsafe extern "C" fn audio_player_create(
    //     mut _obj: *mut ffi::c_void,
    //     starting_volume: ffi::c_uint,
    //     update_timer: unsafe extern "C" fn(Ptr, i64) -> (),
    //     song_preloader: unsafe extern "C" fn(Ptr, *mut mpv_bindings::mpv_handle) -> (),
    //     argument: *mut ffi::c_void,
    // ) -> i32 {
    //     use mpv_bindings::MpvEventData;

    //     macro_rules! err {
    //         ($ex:expr) => {
    //             match $ex {
    //                 Ok(x) => x,
    //                 Err(_) => return 1,
    //             }
    //         };
    //     }
    //     const TIME_POS_ID: u64 = 1;
    //     let mut mpv = err!(mpv_bindings::Mpv::new());
    //     err!(mpv.set_property("volume-max", &100));
    //     err!(mpv.set_property("volume", &(starting_volume as i64)));
    //     err!(mpv.set_property_string("gapless", "weak"));
    //     err!(mpv.set_property_string("vid", "no"));
    //     err!(mpv.observe_property::<i64>("time-pos", TIME_POS_ID));
    //     let arg = Ptr(argument);
    //     err!(mpv.attach(move |obj, event| {
    //         let data = event.data();
    //         match data {
    //             MpvEventData::PropertyInt64 { data, id, .. } if id == TIME_POS_ID => unsafe {
    //                 update_timer(arg.clone(), data)
    //             },
    //             MpvEventData::EndFile(
    //                 mpv_bindings::mpv_end_file_reason::MPV_END_FILE_REASON_EOF,
    //             ) => unsafe { song_preloader(arg.clone(), obj.handle().0) },
    //             _ => {}
    //         }
    //     }));
    //     let raw = Box::into_raw(Box::new(mpv));
    //     _obj = raw as *mut ffi::c_void;
    //     0
    // }

    // /// # Safety
    // /// Do not pass NULL
    // #[no_mangle]
    // pub unsafe extern "C" fn audio_player_free(obj: *mut ffi::c_void) {
    //     let _ = unsafe { Box::from_raw(obj as *mut mpv_bindings::Mpv) };
    // }
}

// pub mod uniffi_api {
//     use crate::database;

//     pub fn scan_directories(paths: Vec<String>, database_file: String) -> u64 {
//         let pool = match database(database_file) {
//             Ok(x) => x,
//             Err(_) => return 1,
//         };
//         for path in paths {
//             if !database::scan_directory(path, pool.clone()).1.is_empty() {
//                 return 1;
//             }
//         }
//         0
//     }
// }
