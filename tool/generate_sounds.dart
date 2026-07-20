import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final sounds = {
    'chime': _generateChime(),
    'bell': _generateBell(),
    'gentle': _generateGentle(),
  };

  final androidRawDir = Directory('android/app/src/main/res/raw');
  final assetsSoundDir = Directory('assets/sounds');
  androidRawDir.createSync(recursive: true);
  assetsSoundDir.createSync(recursive: true);

  for (final entry in sounds.entries) {
    final name = entry.key;
    final data = entry.value;
    File('${androidRawDir.path}/$name.wav').writeAsBytesSync(data);
    File('${assetsSoundDir.path}/$name.wav').writeAsBytesSync(data);
    print('Generated $name.wav (${data.length} bytes)');
  }

  print('Done!');
}

Uint8List _generateChime() {
  const sampleRate = 22050;
  const bitsPerSample = 16;
  const numChannels = 1;
  final note1 = _buildNote(sampleRate, 0.35, 523.25, 0.5);
  final note2 = _buildNote(sampleRate, 0.4, 659.25, 0.5);
  final gap = Uint8List(0);
  final samples = Int16List.fromList([...note1, ...note2]);
  return _encodeWav(samples, sampleRate, bitsPerSample, numChannels);
}

Uint8List _generateBell() {
  const sampleRate = 22050;
  const bitsPerSample = 16;
  const numChannels = 1;
  final samples = _buildNote(sampleRate, 1.2, 880.0, 0.6, decay: 2.0);
  return _encodeWav(samples, sampleRate, bitsPerSample, numChannels);
}

Uint8List _generateGentle() {
  const sampleRate = 22050;
  const bitsPerSample = 16;
  const numChannels = 1;
  final note1 = _buildNote(sampleRate, 0.25, 660.0, 0.35);
  final pause = Int16List((sampleRate * 0.08).toInt());
  final note2 = _buildNote(sampleRate, 0.25, 880.0, 0.35);
  final samples = Int16List.fromList([...note1, ...pause, ...note2]);
  return _encodeWav(samples, sampleRate, bitsPerSample, numChannels);
}

Int16List _buildNote(int sampleRate, double duration, double freq, double volume, {double decay = 0.0}) {
  final count = (sampleRate * duration).toInt();
  final samples = Int16List(count);
  for (int i = 0; i < count; i++) {
    final t = i / sampleRate;
    final env = decay > 0
        ? exp(-t * decay)
        : (1 - t / duration).clamp(0.0, 1.0);
    final harmonic = sin(2 * pi * freq * t) + 0.3 * sin(2 * pi * freq * 2 * t) + 0.1 * sin(2 * pi * freq * 3 * t);
    final val = (32767 * volume * env * harmonic / 1.4).round().clamp(-32767, 32767);
    samples[i] = val;
  }
  return samples;
}

Uint8List _encodeWav(Int16List samples, int sampleRate, int bitsPerSample, int numChannels) {
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = samples.length * blockAlign;
  final fileSize = 44 + dataSize;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final data = ByteData(fileSize);
  int offset = 0;

  void w16(int v) { data.setUint16(offset, v, Endian.little); offset += 2; }
  void w32(int v) { data.setUint32(offset, v, Endian.little); offset += 4; }
  void w8(int v) { data.setUint8(offset++, v); }

  w8(0x52); w8(0x49); w8(0x46); w8(0x46); // RIFF
  w32(fileSize - 8);
  w8(0x57); w8(0x41); w8(0x56); w8(0x45); // WAVE
  w8(0x66); w8(0x6D); w8(0x74); w8(0x20); // fmt 
  w32(16);
  w16(1); w16(numChannels);
  w32(sampleRate);
  w32(byteRate);
  w16(blockAlign);
  w16(bitsPerSample);
  w8(0x64); w8(0x61); w8(0x74); w8(0x61); // data
  w32(dataSize);

  for (int i = 0; i < samples.length; i++) {
    w16(samples[i] & 0xFFFF);
  }

  return data.buffer.asUint8List();
}
