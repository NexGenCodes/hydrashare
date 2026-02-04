use std::io::Read;
use sha2::{Sha256, Digest};
use rkyv::{Archive, Deserialize as RkyvDeserialize, Serialize as RkyvSerialize};
use serde::{Deserialize, Serialize};

pub const BLOCK_SIZE: usize = 1024 * 1024; // 1MB blocks

#[derive(Archive, RkyvDeserialize, RkyvSerialize, Serialize, Deserialize, Debug, Clone)]
#[archive(check_bytes)]
pub struct FileMap {
    pub file_id: String,
    pub block_hashes: Vec<[u8; 32]>,
}

pub struct DeltaHasher;

impl DeltaHasher {
    pub fn compute_map(file_path: &str) -> anyhow::Result<FileMap> {
        let mut file = std::fs::File::open(file_path)?;
        let mut hashes = Vec::new();
        let mut buffer = vec![0u8; BLOCK_SIZE];

        loop {
            let bytes_read = file.read(&mut buffer)?;
            if bytes_read == 0 {
                break;
            }

            let mut hasher = Sha256::new();
            hasher.update(&buffer[..bytes_read]);
            let result = hasher.finalize();
            
            let mut hash = [0u8; 32];
            hash.copy_from_slice(&result);
            hashes.push(hash);
        }

        Ok(FileMap {
            file_id: file_path.to_string(), // In a real app, use a unique file ID or path
            block_hashes: hashes,
        })
    }

    pub fn diff(local: &FileMap, remote: &FileMap) -> Vec<usize> {
        let mut missing_blocks = Vec::new();
        for (i, remote_hash) in remote.block_hashes.iter().enumerate() {
            if i >= local.block_hashes.len() || local.block_hashes[i] != *remote_hash {
                missing_blocks.push(i);
            }
        }
        missing_blocks
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_delta_hashing() {
        let mut file = NamedTempFile::new().unwrap();
        let data = vec![0u8; BLOCK_SIZE + 100];
        file.write_all(&data).unwrap();
        
        let path = file.path().to_str().unwrap();
        let map = DeltaHasher::compute_map(path).unwrap();
        
        assert_eq!(map.block_hashes.len(), 2);
    }

    #[test]
    fn test_delta_diff() {
        let map1 = FileMap {
            file_id: "test".to_string(),
            block_hashes: vec![[0u8; 32], [1u8; 32]],
        };
        let map2 = FileMap {
            file_id: "test".to_string(),
            block_hashes: vec![[0u8; 32], [2u8; 32]],
        };
        
        let missing = DeltaHasher::diff(&map1, &map2);
        assert_eq!(missing, vec![1]);
    }
}
