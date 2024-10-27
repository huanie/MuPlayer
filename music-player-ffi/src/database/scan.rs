use crate::error;
use crate::types::SqlitePool;
use lofty::file::{AudioFile, TaggedFile, TaggedFileExt};
use lofty::tag::{ItemKey, ItemValue};
use rayon::iter::{Either, ParallelBridge};
use rayon::prelude::*;
use std::collections::{HashMap, HashSet};
use std::ffi::OsStr;
use std::os::unix::fs::MetadataExt;
use std::path::{self, Path, PathBuf};
use walkdir::WalkDir;
const UNKNOWN: &str = "UNKNOWN";
const NO_NUM: u32 = 1;

/// Scan the directory `root` for music files.
/// Stores them in the database `pool`.
///
/// Returns `([usize], [Vec<error::ScanError>])`, first element being the number of successful processed files and second element being the errors encountered in all other files.
///
/// Not existing album artist, album, track title, track number or disc number will not count as an error, relevant defaults will be given
pub fn scan_directory<P: AsRef<Path> + std::marker::Sync + std::marker::Send>(
    root: P,
    pool: SqlitePool,
) -> (usize, Vec<error::ScanError>) {
    let pool_cl = pool.clone();
    {
        let conn = pool_cl.get().unwrap();
        conn.execute(
            "INSERT OR IGNORE INTO directory(path) VALUES (?1)",
            [root.as_ref().to_str().unwrap()],
        )
        .unwrap();
    }

    let extensions = HashSet::from([
        OsStr::new("flac"),
        OsStr::new("mp3"),
        OsStr::new("ogg"),
        OsStr::new("wav"),
        OsStr::new("m4a"),
        OsStr::new("vorbis"),
        OsStr::new("opus"),
    ]);
    let (oks, errs): (Vec<()>, Vec<error::ScanError>) = WalkDir::new(&root)
        .into_iter()
        .par_bridge()
        .filter_map(|x| match &x {
            Ok(f)
                if f.file_type().is_file()
                    && f.path()
                        .extension()
                        .map_or(false, |ext| extensions.contains(ext)) =>
            {
                x.ok()
            }
            _ => None,
        })
        .partition_map(|x| {
            let path = x.path();
            insert_into(path, root.as_ref(), pool.clone())
        });

    let conn = pool_cl.get().unwrap();
    conn.execute(
        r#"
INSERT INTO song_search(title,
  artist_name,
  album_title,
  path
)
SELECT title, album_artist, album_title, path FROM song"#,
        [],
    )
    .unwrap();

    (oks.len(), errs)
}

/// Just delete all data from the Database and rescan
pub fn rescan_directory<P: AsRef<Path> + std::marker::Sync + std::marker::Send>(
    root: P,
    pool: SqlitePool,
) -> (usize, Vec<error::ScanError>) {
    {
        let conn = pool.get().unwrap();
        conn.execute_batch(
            r#"
DELETE FROM artist;
DELETE FROM album;
DELETE FROM directory;
DELETE FROM song;
DELETE FROM song_search;
"#,
        )
        .unwrap();
    }
    scan_directory(root, pool)
}

/// Scan and insert into database
fn insert_into(path: &Path, root: &Path, pool: SqlitePool) -> Either<(), error::ScanError> {
    macro_rules! either {
        ($ex:expr) => {
            match $ex {
                Ok(x) => x,
                Err(e) => return Either::Right(error::ScanError::from(e)),
            }
        };
    }
    let tagged = either! {
        lofty::read_from_path(path)
    };
    let (tags, duration, path) = either!(extract_metadata(&tagged, path));
    macro_rules! return_tag {
        (NO_NUM, $x:expr) => {
            $x.chars()
                .map_while(|c| c.to_digit(10))
                .fold(0, |acc, digit| acc * 10 + digit)
        };
        (UNKNOWN, $x:expr) => {
            $x
        };
    }

    macro_rules! get_tag {
        ($tag:expr, $rt:ident) => {
            match unsafe { tags.get(&$tag).unwrap_unchecked() } {
                Some(val) => val.text().map_or_else(|| $rt, |x| return_tag!($rt, x)),
                None => $rt,
            }
        };
    }
    let disc_number = get_tag!(ItemKey::DiscNumber, NO_NUM);
    let track_number = get_tag!(ItemKey::TrackNumber, NO_NUM);
    let album = get_tag!(ItemKey::AlbumTitle, UNKNOWN);
    let title = get_tag!(ItemKey::TrackTitle, UNKNOWN);
    let album_artist = unsafe { tags.get(&ItemKey::AlbumArtist).unwrap_unchecked() };
    let track_artist = get_tag!(ItemKey::TrackArtist, UNKNOWN);
    let artist = album_artist.map_or(track_artist, |x| x.text().unwrap_or(track_artist));

    let mtime = path.metadata().unwrap().mtime();
    let mut conn = pool.get().unwrap();

    let transaction = conn.transaction().unwrap();
    if track_number == 1 && disc_number == 1 {
        transaction
            .prepare_cached("INSERT OR IGNORE INTO artist (artist_name) VALUES (?1)")
            .unwrap()
            .execute([artist])
            .unwrap();
        transaction
            .prepare_cached("INSERT INTO album (album_title, artist_name) VALUES (?1, ?2)")
            .unwrap()
            .execute(rusqlite::params![album, artist])
            .unwrap();
    }
    transaction.prepare_cached(r#"
INSERT OR IGNORE
INTO song (disc_number, path, title, modified_stamp, artist_name, track_number, duration, album_title, directory, album_artist)
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
"#).unwrap().execute(
    rusqlite::params![disc_number, path.to_str().unwrap(), title, mtime, track_artist, track_number, duration, album, root.to_str().unwrap(), artist]).unwrap();
    transaction.commit().unwrap();

    Either::Left(())
}

// /// Extract the cover from the `tagged` TaggedFile and write it into the `path` directory.
// /// The file name will be randomly generated with rng.
// /// Returns the cover hash and cover path when there is a cover, None when there is no cover.
// fn create_cover<P: AsRef<Path>>(path: P, tagged: &TaggedFile) -> Option<(String, PathBuf)> {
//     use lofty::picture::MimeType;
//     use rand::distributions::{Alphanumeric, DistString};
//     let tags = tagged.primary_tag()?;
//     let mut rng = SmallRng::from_entropy();
//     let cover = tags.pictures().first()?;

//     let data = cover.data();
//     let mime = cover.mime_type()?;
//     let extension = match mime {
//         MimeType::Png => Some(".png"),
//         MimeType::Jpeg => Some(".jpg"),
//         MimeType::Tiff => Some(".tiff"),
//         MimeType::Bmp => Some(".bmp"),
//         MimeType::Gif => Some(".gif"),
//         MimeType::Unknown(_) => None,
//         _ => None,
//     }?;
//     let hash = blake3::hash(data).to_string();
//     trait X {
//         fn append(self, other: &str) -> String;
//     }
//     impl X for String {
//         fn append(mut self, other: &str) -> String {
//             self.push_str(other);
//             self
//         }
//     }
//     let mut cover_path = path
//         .as_ref()
//         .join(Alphanumeric.sample_string(&mut rng, 10).append(extension));
//     loop {
//         match std::fs::File::create_new(&cover_path) {
//             Ok(mut file) => {
//                 file.write_all(data).ok()?;
//                 file.flush().ok()?;
//                 return Some((hash, cover_path));
//             }
//             Err(x) if x.kind() == std::io::ErrorKind::AlreadyExists => {
//                 cover_path = path
//                     .as_ref()
//                     .join(Alphanumeric.sample_string(&mut rng, 10).append(extension));
//                 continue;
//             }
//             Err(_) => return None,
//         }
//     }
// }

type SongRef<'a> = HashMap<&'a ItemKey, Option<&'a ItemValue>>;
type Metadata<'a> = (SongRef<'a>, u64, PathBuf);
fn extract_metadata<P: AsRef<Path>>(
    tagged: &TaggedFile,
    path: P,
) -> Result<Metadata<'_>, error::ScanError> {
    let props = tagged.properties();
    let duration = props.duration().as_secs();
    let tags = tagged.primary_tag();
    let mut song: SongRef = HashMap::from([
        (&ItemKey::AlbumArtist, None),
        (&ItemKey::TrackArtist, None),
        (&ItemKey::AlbumTitle, None),
        (&ItemKey::TrackTitle, None),
        (&ItemKey::TrackNumber, None),
        (&ItemKey::DiscNumber, None),
    ]);
    if let Some(tag_items) = tags {
        // Tag::get is O(N) for each call
        let mut queue: HashSet<&ItemKey> = song.keys().cloned().collect();
        for x in tag_items.items() {
            if queue.is_empty() {
                break;
            }
            match song.entry(x.key()) {
                std::collections::hash_map::Entry::Occupied(mut entry) => {
                    entry.insert(Some(x.value()));
                    queue.remove(x.key());
                }
                std::collections::hash_map::Entry::Vacant(_) => continue,
            }
        }
    }
    Ok((song, duration, path::absolute(path)?))
}
