import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final _player = AudioPlayer();
  Uint8List? _beepData;

  Future<void> playBeep() async {
    _beepData ??= _generateBeep();
    await _player.stop();
    await _player.play(BytesSource(_beepData!));
  }

  Uint8List _generateBeep() {
    final sampleRate = 8000;
    final durationSeconds = 0.3;
    final frequency = 880.0;
    final bitsPerSample = 16;
    final numChannels = 1;
    final numSamples = (sampleRate * durationSeconds).toInt();
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final fileSize = 44 + dataSize;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;

    final data = ByteData(fileSize);
    var offset = 0;

    void writeUint16(int v) { data.setUint16(offset, v, Endian.little); offset += 2; }
    void writeUint32(int v) { data.setUint32(offset, v, Endian.little); offset += 4; }
    void writeString(String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    writeString('RIFF');
    writeUint32(fileSize - 8);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(dataSize);

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = (1 - t / durationSeconds).clamp(0.0, 1.0);
      final sample = (32767 * 0.4 * envelope * sin(2 * pi * frequency * t)).round().clamp(-32767, 32767);
      data.setUint16(offset, sample & 0xFFFF, Endian.little);
      offset += 2;
    }

    return data.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
