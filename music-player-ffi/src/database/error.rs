use thiserror::Error;

#[derive(Error, Debug)]
pub enum ScanError {
    #[error(transparent)]
    MetadataError(#[from] lofty::error::LoftyError),
    #[error(transparent)]
    FileError(#[from] std::io::Error),
    #[error(transparent)]
    DatabaseError(#[from] rusqlite::Error),
    #[error("No cover")]
    NoCover,
}
