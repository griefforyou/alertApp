import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final _player = AudioPlayer();
  final Map<String, Uint8List> _cache = {};

  Future<void> playBuiltin(String name) async {
    final data = _getSound(name);
    await _player.stop();
    await _player.play(BytesSource(data));
  }

  Future<void> playBeep() => playBuiltin('gentle');

  Uint8List _getSound(String name) {
    if (_cache.containsKey(name)) return _cache[name]!;
    final data = _generate(name);
    _cache[name] = data;
    return data;
  }

  Uint8List _generate(String name) {
    switch (name) {
      case 'chime':
        return _generateChime();
      case 'bell':
        return _generateBell();
      default:
        return _generateGentle();
    }
  }

  Uint8List _generateChime() {
    const sr = 22050;
    final note1 = _buildNote(sr, 0.35, 523.25, 0.5);
    final note2 = _buildNote(sr, 0.4, 659.25, 0.5);
    final samples = Int16List(note1.length + note2.length);
    samples.setAll(0, note1);
    samples.setAll(note1.length, note2);
    return _encodeWav(samples, sr);
  }

  Uint8List _generateBell() {
    const sr = 22050;
    return _encodeWav(_buildNote(sr, 1.2, 880.0, 0.6, decay: 2.0), sr);
  }

  Uint8List _generateGentle() {
    const sr = 22050;
    final note1 = _buildNote(sr, 0.25, 660.0, 0.35);
    final pause = Int16List((sr * 0.08).toInt());
    final note2 = _buildNote(sr, 0.25, 880.0, 0.35);
    final samples = Int16List(note1.length + pause.length + note2.length);
    samples.setAll(0, note1);
    samples.setAll(note1.length, pause);
    samples.setAll(note1.length + pause.length, note2);
    return _encodeWav(samples, sr);
  }

  Int16List _buildNote(int sr, double duration, double freq, double volume, {double decay = 0.0}) {
    final count = (sr * duration).toInt();
    final samples = Int16List(count);
    for (int i = 0; i < count; i++) {
      final t = i / sr;
      final env = decay > 0 ? exp(-t * decay) : (1 - t / duration).clamp(0.0, 1.0);
      final h = sin(2 * pi * freq * t) + 0.3 * sin(2 * pi * freq * 2 * t) + 0.1 * sin(2 * pi * freq * 3 * t);
      samples[i] = (32767 * volume * env * h / 1.4).round().clamp(-32767, 32767);
    }
    return samples;
  }

  Uint8List _encodeWav(Int16List samples, int sr) {
    final bps = 16;
    final ch = 1;
    final ba = ch * bps ~/ 8;
    final ds = samples.length * ba;
    final fs = 44 + ds;
    final br = sr * ch * bps ~/ 8;
    final data = ByteData(fs);
    int o = 0;

    void w16(int v) { data.setUint16(o, v, Endian.little); o += 2; }
    void w32(int v) { data.setUint32(o, v, Endian.little); o += 4; }
    void w8(int v) { data.setUint8(o++, v); }

    const h = [0x52,0x49,0x46,0x46]; for (final b in h) w8(b); // RIFF
    w32(fs - 8);
    const w = [0x57,0x41,0x56,0x45]; for (final b in w) w8(b); // WAVE
    const f = [0x66,0x6D,0x74,0x20]; for (final b in f) w8(b); // fmt 
    w32(16); w16(1); w16(ch); w32(sr); w32(br); w16(ba); w16(bps);
    const d = [0x64,0x61,0x74,0x61]; for (final b in d) w8(b); // data
    w32(ds);

    for (int i = 0; i < samples.length; i++) w16(samples[i] & 0xFFFF);

    return data.buffer.asUint8List();
  }

  void dispose() {
    _player.dispose();
  }
}
