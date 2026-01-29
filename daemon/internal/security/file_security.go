package security

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

const (
	MaxFileSize = 2 * 1024 * 1024 * 1024 // 2GB
)

// Blocked file extensions (dangerous executable types)
var BlockedExtensions = []string{
	".exe", ".bat", ".cmd", ".scr", ".vbs", ".js",
	".jar", ".apk", ".dmg", ".pkg", ".deb", ".rpm",
	".msi", ".com", ".pif", ".application", ".gadget",
	".msp", ".ps1", ".psm1", ".sh", ".bash", ".zsh",
}

type FileValidator struct {
	MaxSize           int64
	BlockedExtensions []string
}

func NewFileValidator() *FileValidator {
	return &FileValidator{
		MaxSize:           MaxFileSize,
		BlockedExtensions: BlockedExtensions,
	}
}

// ValidateFile performs comprehensive security checks on a file
func (v *FileValidator) ValidateFile(filePath string) error {
	// Check if file exists
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		return fmt.Errorf("file not found: %w", err)
	}

	// Check if it's a regular file
	if !fileInfo.Mode().IsRegular() {
		return fmt.Errorf("not a regular file")
	}

	// Check file size
	if fileInfo.Size() > v.MaxSize {
		return fmt.Errorf("file size (%d bytes) exceeds maximum allowed size (%d bytes)", fileInfo.Size(), v.MaxSize)
	}

	if fileInfo.Size() == 0 {
		return fmt.Errorf("file is empty")
	}

	// Check extension
	ext := strings.ToLower(filepath.Ext(filePath))
	for _, blocked := range v.BlockedExtensions {
		if ext == blocked {
			return fmt.Errorf("file type %s is blocked for security reasons", ext)
		}
	}

	// Validate MIME type matches extension
	if err := v.validateMIMEType(filePath, ext); err != nil {
		return err
	}

	return nil
}

// validateMIMEType checks if the file's actual content matches its extension
func (v *FileValidator) validateMIMEType(filePath string, ext string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	// Read first 512 bytes for MIME detection
	buffer := make([]byte, 512)
	n, err := file.Read(buffer)
	if err != nil && err != io.EOF {
		return err
	}

	// Detect MIME type from content
	detectedMIME := http.DetectContentType(buffer[:n])

	// Basic check: if extension is .txt, content should be text/plain or similar
	expectedMIME := mime.TypeByExtension(ext)
	if expectedMIME != "" {
		// We use Split for cases like "text/plain; charset=utf-8"
		detectedBase := strings.Split(detectedMIME, ";")[0]
		expectedBase := strings.Split(expectedMIME, ";")[0]

		// Allow generic octet-streams if detected from content, but be wary of mismatching major types
		if !v.isMimeCompatible(detectedBase, expectedBase) {
			return fmt.Errorf("security mismatch: file content (%s) does not match extension (%s/%s)", detectedBase, ext, expectedBase)
		}
	}

	return nil
}

func (v *FileValidator) isMimeCompatible(detected, expected string) bool {
	if detected == expected || detected == "application/octet-stream" {
		return true
	}
	// Allow text variants
	if strings.HasPrefix(detected, "text/") && strings.HasPrefix(expected, "text/") {
		return true
	}
	return false
}

// SanitizeFilename removes dangerous characters from filenames
func SanitizeFilename(filename string) string {
	// Remove path separators and traversal attempts
	filename = filepath.Base(filename)
	filename = strings.ReplaceAll(filename, "..", "")
	filename = strings.ReplaceAll(filename, "/", "")
	filename = strings.ReplaceAll(filename, "\\", "")

	// Remove null bytes and control characters
	filename = strings.Map(func(r rune) rune {
		if r < 32 || r == 127 {
			return -1
		}
		return r
	}, filename)

	// Limit filename length
	if len(filename) > 255 {
		ext := filepath.Ext(filename)
		base := filename[:255-len(ext)]
		filename = base + ext
	}

	// If filename is empty after sanitization, use a default
	if filename == "" {
		filename = "unnamed_file"
	}

	return filename
}

// CalculateFileHash calculates SHA-256 hash of a file
func CalculateFileHash(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hasher.Sum(nil)), nil
}

// FileMetadata contains information about a file to be transferred
type FileMetadata struct {
	Name      string `json:"name"`
	Size      int64  `json:"size"`
	Hash      string `json:"hash"`
	Extension string `json:"extension"`
	MIMEType  string `json:"mime_type"`
}

// GetFileMetadata extracts metadata from a file
func GetFileMetadata(filePath string) (*FileMetadata, error) {
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		return nil, err
	}

	hash, err := CalculateFileHash(filePath)
	if err != nil {
		return nil, err
	}

	ext := filepath.Ext(filePath)
	mimeType := mime.TypeByExtension(ext)

	return &FileMetadata{
		Name:      filepath.Base(filePath),
		Size:      fileInfo.Size(),
		Hash:      hash,
		Extension: ext,
		MIMEType:  mimeType,
	}, nil
}
