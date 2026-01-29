package main

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

func main() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: verify_decryption <enc_file> <key> <output_file>")
		os.Exit(1)
	}

	encPath := os.Args[1]
	keyStr := os.Args[2]
	outPath := os.Args[3]

	// Open encrypted file
	f, err := os.Open(encPath)
	if err != nil {
		panic(err)
	}
	defer f.Close()

	// Decode Key
	keyBytes, err := base64.StdEncoding.DecodeString(keyStr)
	if err != nil {
		panic(fmt.Sprintf("Invalid key: %v", err))
	}

	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		panic(err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		panic(err)
	}

	// Read Header Nonce
	hNonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(f, hNonce); err != nil {
		panic("Failed to read header nonce")
	}

	// Read Header Length
	var hLen uint32
	if err := binary.Read(f, binary.BigEndian, &hLen); err != nil {
		panic("Failed to read header len")
	}

	// Read Header Cipher
	hCipher := make([]byte, hLen)
	if _, err := io.ReadFull(f, hCipher); err != nil {
		panic("Failed to read header cipher")
	}

	// Decrypt Header
	hPlain, err := gcm.Open(nil, hNonce, hCipher, nil)
	if err != nil {
		panic(fmt.Sprintf("Header decryption failed: %v", err))
	}

	fmt.Printf("✅ Header Decrypted: %s\n", string(hPlain))

	// Read File Nonce
	fNonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(f, fNonce); err != nil {
		panic("Failed to read file nonce")
	}

	// Open Output File
	outF, err := os.Create(outPath)
	if err != nil {
		panic(err)
	}
	defer outF.Close()

	// Read Chunks
	chunkBuf := make([]byte, 1024*1024+1024)
	totalBytes := 0

	for {
		var cLen uint32
		err := binary.Read(f, binary.BigEndian, &cLen)
		if err == io.EOF {
			break
		}
		if err != nil {
			panic("Failed to read chunk len")
		}

		if int(cLen) > len(chunkBuf) {
			chunkBuf = make([]byte, cLen+1024)
		}

		if _, err := io.ReadFull(f, chunkBuf[:cLen]); err != nil {
			panic("Failed to read chunk cipher")
		}

		plain, err := gcm.Open(nil, fNonce, chunkBuf[:cLen], nil)
		if err != nil {
			panic(fmt.Sprintf("Chunk decryption failed: %v", err))
		}

		outF.Write(plain)
		totalBytes += len(plain)
	}

	fmt.Printf("✅ Body Decrypted: %d bytes\n", totalBytes)
}
