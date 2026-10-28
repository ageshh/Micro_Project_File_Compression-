# Mobile-Optimized Universal Data Compression Utility (MUDC)

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Flutter-02569B.svg?logo=flutter)](#)
[![Algorithm](https://img.shields.io/badge/Pipeline-LZ77%20%2B%20Huffman%20(Deflate)-orange.svg)](#)
[![Extraction](https://img.shields.io/badge/Extraction-100%25%20Lossless-green.svg)](#)

A standalone, software-based universal data archiver designed for constrained mobile computing environments. Built from scratch without external compression libraries, the utility processes files as raw binary streams and implements a custom two-stage **Deflate (LZ77 + Canonical Huffman Encoding)** pipeline to output lossless **`.mudc`** archives.

---

## 📌 Abstract

This project details the development of a universal, software-based file archiver built from scratch to optimize data transmission over mobile networks. Rather than relying on external libraries, the utility implements the core Deflate architecture using a custom two-stage compression pipeline.

By processing inputs as raw binary streams, the tool can compress any file format seamlessly. It achieves this by first applying the LZ77 algorithm, utilizing a sliding window to replace repeating byte sequences with distance-length pointers. This intermediate data is then processed by a Huffman encoder, which assigns optimal variable-length bit codes based on byte frequency, drastically shrinking the final data footprint.

To guarantee accurate lossless extraction, the payload is packaged with a custom metadata header containing the original file signature and dimensions. In practice, this utility directly addresses the limitations of mobile computing by significantly reducing bandwidth consumption, minimizing storage requirements on edge devices, and accelerating peer-to-peer file transfers across constrained cellular or ad-hoc networks.

---

## ⚙️ Architecture & Working Mechanism

The utility operates on a strict raw binary pipeline:

```text
                        Raw Input Bytestream
                                 │
                                 ▼
              ┌──────────────────────────────────────┐
              │        Stage 1: LZ77 Encoder         │
              │   (Sliding Window Dictionary Match)  │
              └──────────────────┬───────────────────┘
                                 │
                       Stream of LZ77 Tokens:
                     - Literals (unmatched bytes)
                     - Matches (distance, length)
                                 │
                                 ▼
              ┌──────────────────────────────────────┐
              │        Stage 2: Huffman Encoder      │
              │    (Optimal Variable-Length Codes)   │
              └──────────────────┬───────────────────┘
                                 │
                                 ▼
              ┌──────────────────────────────────────┐
              │        MUDC Container Packer         │
              │   (Magic Signature + Header Data)    │
              └──────────────────┬───────────────────┘
                                 │
                                 ▼
                        Output (.mudc Archive)
```


### 1. Stage 1: LZ77 Sliding Window Matching
* Scans the incoming binary stream through a configurable sliding window buffer.
* Replaces repetitive byte patterns with backward references: `(distance, length)`.
* Emits intermediate tokens:
  * `Lz77Literal`: Individual unmatched bytes.
  * `Lz77Match`: Offset distance and length pointing back into the dictionary window.

### 2. Stage 2: Canonical Huffman Coding
* Analyzes the frequency table of the intermediate LZ77 token stream.
* Builds a prefix tree assigning shorter bit representations to frequent symbols and longer codes to rarer ones.
* Encodes the data into a dense, variable-length bitstream.

### 3. The Custom `.mudc` Binary Container
Compressed payloads are packaged with a custom metadata header for lossless extraction:
* **Magic Bytes (`0x00 - 0x03`):** ASCII `"MUDC"` signature verification.
* **Format Version (`0x04`):** Container version tracking.
* **Original Dimensions (`0x05 - 0x0C`):** 64-bit integer tracking the uncompressed byte count to prevent truncated decompression.
* **Frequency Table:** Encoded symbol frequency headers used to reconstruct the identical Huffman tree on extraction.
* **Compressed Bitstream:** Packed variable-length bitstream.

---

## 🚀 Key Features

* **Universal Format Support:** Binary-level compression compatible with any extension (`.txt`, `.pdf`, `.png`, `.wav`, etc.).
* **100% Lossless Restoration:** Reconstructed data matches the original byte stream bit-for-bit.
* **Asynchronous Background Workers:** Compression and decompression tasks run on separate worker threads (`Isolates`) to ensure fluid 60 FPS mobile UI performance.
* **Interactive Dashboard:**
  * Real-time metrics: Original Size, Compressed Size, Compression Ratio (`Comp. Ratio`), and Space Savings (`%`).
  * Configurable sliding window buffer for tuning CPU/memory vs. compression ratio.
  * Dual input support: Direct text payload editor and native file browser.
* **Specialized Optimization Utilities:** Dedicated handling for PNGs, PDFs, Audio (`.mp3`/`.wav`), and Video (`.mp4`/`.mkv`).

---

## 📂 Project Structure

```text
├── lib/
│   ├── main.dart             # App entry point & MudcDashboard UI
│   ├── compressor.dart       # Core MudcCompressor, LZ77 engine, and Huffman tree logic
│   ├── file_saver.dart       # Storage & download management for mobile devices
│   ├── png_compressor.dart   # Dedicated image preprocessing module
│   ├── pdf_compressor.dart   # Document stream optimizer
│   ├── audio_compressor.dart # Audio stream compressor
│   └── video_compressor.dart # Video stream compressor
└── base.apk                  # Compiled Android release binary

## 📥 Download & Installation

1. Go to the [Releases](https://github.com/ageshh/Micro_Project_File_Compression-/releases) tab (or root directory).
2. Download `base.apk`.
3. On your Android device, allow installation from unknown sources and install the APK.
