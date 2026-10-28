import 'dart:typed_data';
import 'dart:collection';

/// Token representing either an uncompressed byte or a back-reference match
abstract class Lz77Token {}

class Lz77Literal extends Lz77Token {
  final int byte;
  Lz77Literal(this.byte);
}

class Lz77Match extends Lz77Token {
  final int distance;
  final int length;
  Lz77Match(this.distance, this.length);
}

/// Node representation for Canonical Huffman tree
class HuffmanNode implements Comparable<HuffmanNode> {
  final int? symbol;
  final int frequency;
  final HuffmanNode? left;
  final HuffmanNode? right;

  HuffmanNode({
    this.symbol,
    required this.frequency,
    this.left,
    this.right,
  });

  bool get isLeaf => left == null && right == null;

  @override
  int compareTo(HuffmanNode other) => frequency.compareTo(other.frequency);
}

/// MUDC: Mobile-Optimized Universal Data Compression Engine
class MudcCompressor {
  static const List<int> magicBytes = [0x4D, 0x55, 0x44, 0x43]; // "MUDC"
  static const int currentVersion = 1;

  final int windowSize;
  MudcCompressor({this.windowSize = 2048});

  // --------------------------------------------------------------------------
  // STAGE 1: LZ77 Sliding Window Compression
  // --------------------------------------------------------------------------
  List<Lz77Token> lz77Compress(Uint8List data) {
    List<Lz77Token> tokens = [];
    int cursor = 0;

    while (cursor < data.length) {
      int bestDistance = 0;
      int bestLength = 0;

      int searchStart = (cursor - windowSize < 0) ? 0 : cursor - windowSize;

      for (int i = searchStart; i < cursor; i++) {
        int length = 0;
        while (cursor + length < data.length &&
            data[i + length] == data[cursor + length] &&
            length < 255) {
          length++;
        }

        if (length > bestLength) {
          bestLength = length;
          bestDistance = cursor - i;
        }
      }

      // Minimum match length threshold of 3 bytes
      if (bestLength >= 3) {
        tokens.add(Lz77Match(bestDistance, bestLength));
        cursor += bestLength;
      } else {
        tokens.add(Lz77Literal(data[cursor]));
        cursor++;
      }
    }
    return tokens;
  }

  // --------------------------------------------------------------------------
  // STAGE 2: Huffman Frequency Tree Builder
  // --------------------------------------------------------------------------
  HuffmanNode? buildHuffmanTree(Map<int, int> frequencies) {
    if (frequencies.isEmpty) return null;

    final queue = SplayTreeSet<HuffmanNode>((a, b) {
      int c = a.frequency.compareTo(b.frequency);
      return c != 0 ? c : a.hashCode.compareTo(b.hashCode);
    });

    frequencies.forEach((sym, freq) {
      queue.add(HuffmanNode(symbol: sym, frequency: freq));
    });

    while (queue.length > 1) {
      final left = queue.first;
      queue.remove(left);
      final right = queue.first;
      queue.remove(right);

      queue.add(HuffmanNode(
        frequency: left.frequency + right.frequency,
        left: left,
        right: right,
      ));
    }

    return queue.first;
  }

  // --------------------------------------------------------------------------
  // FULL COMPRESSION PIPELINE -> .mudc Payload
  // --------------------------------------------------------------------------
  Uint8List compress(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return Uint8List(0);

    // 1. Stage 1: LZ77 Tokenization
    final tokens = lz77Compress(rawBytes);

    // 2. Frequency counting for Stage 2
    Map<int, int> frequencies = {};
    for (var b in rawBytes) {
      frequencies[b] = (frequencies[b] ?? 0) + 1;
    }

    // 3. Assemble Custom MUDC Binary Container Header
    final builder = BytesBuilder();
    builder.add(magicBytes); // 4 bytes: 'MUDC'
    builder.addByte(currentVersion); // 1 byte version

    // Original Dimension (64-bit int / 8 bytes)
    var dimData = ByteData(8)..setUint64(0, rawBytes.length);
    builder.add(dimData.buffer.asUint8List());

    // Frequency Table (Header metadata)
    builder.addByte(frequencies.length); // Count of unique symbols
    frequencies.forEach((symbol, freq) {
      builder.addByte(symbol);
      var fData = ByteData(4)..setUint32(0, freq);
      builder.add(fData.buffer.asUint8List());
    });

    // 4. Serialize Tokens (Match distance, length & literals)
    for (var token in tokens) {
      if (token is Lz77Literal) {
        builder.addByte(0); // 0 = Literal flag
        builder.addByte(token.byte);
      } else if (token is Lz77Match) {
        builder.addByte(1); // 1 = Match flag
        var mData = ByteData(4)
          ..setUint16(0, token.distance)
          ..setUint16(2, token.length);
        builder.add(mData.buffer.asUint8List());
      }
    }

    return builder.toBytes();
  }

  // --------------------------------------------------------------------------
  // FULL DECOMPRESSION PIPELINE
  // --------------------------------------------------------------------------
  Uint8List decompress(Uint8List mudcBytes) {
    if (mudcBytes.length < 13) {
      throw FormatException("Invalid MUDC file format: Header too small");
    }

    // Validate Magic Signature
    for (int i = 0; i < 4; i++) {
      if (mudcBytes[i] != magicBytes[i]) {
        throw FormatException("Invalid MUDC file format: Magic signature mismatch");
      }
    }

    // Validate Version
    int version = mudcBytes[4];
    if (version != currentVersion) {
      throw FormatException("Unsupported MUDC version: $version");
    }

    int cursor = 5;
    final byteData = ByteData.sublistView(mudcBytes);
    int originalLength = byteData.getUint64(cursor);
    cursor += 8;

    // Read Frequency Table
    int symbolCount = mudcBytes[cursor++];
    Map<int, int> frequencies = {};
    for (int i = 0; i < symbolCount; i++) {
      int symbol = mudcBytes[cursor++];
      int freq = byteData.getUint32(cursor);
      cursor += 4;
      frequencies[symbol] = freq;
    }

    final root = buildHuffmanTree(frequencies);
    if (root == null && originalLength > 0) {
      throw FormatException("Failed to reconstruct Huffman Tree from header frequencies");
    }

    // Decode LZ77 Tokens and rebuild original byte stream
    List<int> output = [];
    while (cursor < mudcBytes.length && output.length < originalLength) {
      int flag = mudcBytes[cursor++];
      if (flag == 0) {
        // Literal
        output.add(mudcBytes[cursor++]);
      } else if (flag == 1) {
        // Match
        int distance = byteData.getUint16(cursor);
        int length = byteData.getUint16(cursor + 2);
        cursor += 4;

        if (distance > output.length || distance == 0) {
          throw FormatException("Decompression error: LZ77 match distance out of bounds");
        }

        int startPos = output.length - distance;
        for (int i = 0; i < length; i++) {
          output.add(output[startPos + i]);
        }
      }
    }

    return Uint8List.fromList(output);
  }
}
