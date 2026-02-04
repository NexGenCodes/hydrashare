use image::imageops::FilterType;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use std::io::Cursor;
use tracing::{debug, warn};

pub struct PreviewGenerator;

impl PreviewGenerator {
    pub fn generate_thumbnail(path: &str) -> Option<String> {
        let path_obj = std::path::Path::new(path);
        let ext = path_obj.extension()?.to_str()?.to_lowercase();

        // Only process common image formats
        if !["jpg", "jpeg", "png", "webp"].contains(&ext.as_str()) {
            return None;
        }

        debug!("Generating thumbnail for: {}", path);

        let img = match image::open(path) {
            Ok(img) => img,
            Err(e) => {
                warn!("Failed to open image for thumbnail: {}", e);
                return None;
            }
        };

        // Resize to max 128x128 while preserving aspect ratio
        let thumbnail = img.resize(128, 128, FilterType::Lanczos3);

        let mut buf = Cursor::new(Vec::new());
        // Encode as JPEG with 70% quality for small size
        match thumbnail.write_to(&mut buf, image::ImageFormat::Jpeg) {
            Ok(_) => {
                let bytes = buf.into_inner();
                debug!("Thumbnail generated, size: {} bytes", bytes.len());
                Some(STANDARD.encode(bytes))
            }
            Err(e) => {
                warn!("Failed to encode thumbnail: {}", e);
                None
            }
        }
    }
}
