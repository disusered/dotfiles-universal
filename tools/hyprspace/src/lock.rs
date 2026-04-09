use std::fs::{self, File};
use std::path::{Path, PathBuf};

use fs2::FileExt;

pub struct SpawnLock {
    file: File,
    path: PathBuf,
}

impl SpawnLock {
    /// Try to acquire an exclusive lock for a context.
    /// Returns None if already locked (another spawn in progress).
    pub fn try_acquire(context_id: &str) -> Option<Self> {
        let sanitized = context_id.replace(['/', ' '], "_");
        let path = PathBuf::from(format!("/tmp/hyprspace-{}.lock", sanitized));
        let file = File::create(&path).ok()?;
        file.try_lock_exclusive().ok()?;
        Some(SpawnLock { file, path })
    }

    #[allow(dead_code)]
    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for SpawnLock {
    fn drop(&mut self) {
        let _ = self.file.unlock();
        let _ = fs::remove_file(&self.path);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn acquire_succeeds() {
        let lock = SpawnLock::try_acquire("test_acquire_succeeds");
        assert!(lock.is_some());
    }

    #[test]
    fn double_acquire_fails() {
        let first = SpawnLock::try_acquire("test_double_acquire");
        assert!(first.is_some());
        let second = SpawnLock::try_acquire("test_double_acquire");
        assert!(second.is_none());
    }

    #[test]
    fn releases_on_drop() {
        {
            let lock = SpawnLock::try_acquire("test_releases_on_drop");
            assert!(lock.is_some());
        }
        let lock = SpawnLock::try_acquire("test_releases_on_drop");
        assert!(lock.is_some());
    }

    #[test]
    fn path_sanitization() {
        let lock = SpawnLock::try_acquire("/home/user/project dir");
        assert!(lock.is_some());
        let lock = lock.unwrap();
        let path_str = lock.path().to_string_lossy();
        assert!(
            path_str.contains("_home_user_project_dir"),
            "expected sanitized path, got: {}",
            path_str
        );
    }
}
