// Generates the ScanMyNet launcher-icon source images into assets/icon/.
//
//   dart run tool/generate_icon.dart
//
// Produces (1024x1024):
//   icon.png            full-bleed gradient + radar mark (iOS / legacy Android)
//   icon_background.png blue->cyan gradient        (Android adaptive background)
//   icon_foreground.png transparent + radar mark   (Android adaptive foreground)
//
// Then `dart run flutter_launcher_icons` rasterises every density.
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

const int size = 1024;

// Brand gradient: deep blue -> cyan (matches the in-app progress bar).
const List<int> _blue = [21, 101, 192]; // #1565C0
const List<int> _cyan = [0, 184, 212]; // #00B8D4

img.Image _gradient() {
  final im = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * (size - 1)); // diagonal top-left -> bottom-right
      im.setPixelRgba(
        x,
        y,
        (_blue[0] + (_cyan[0] - _blue[0]) * t).round(),
        (_blue[1] + (_cyan[1] - _blue[1]) * t).round(),
        (_blue[2] + (_cyan[2] - _blue[2]) * t).round(),
        255,
      );
    }
  }
  return im;
}

// Soft-edged coverage (0..1) of a filled disk of [radius] at distance [d].
double _disk(double d, double radius) {
  const e = 1.6; // edge softness for anti-aliasing
  if (d <= radius - e) return 1;
  if (d >= radius + e) return 0;
  return (radius + e - d) / (2 * e);
}

// Coverage of a ring band between [inner] and [outer].
double _ring(double d, double inner, double outer) =>
    (_disk(d, outer) - _disk(d, inner)).clamp(0.0, 1.0);

/// White "signal" mark — a centre dot inside concentric rings — on a
/// transparent canvas. [scale] shrinks it to fit the adaptive safe zone.
img.Image _mark(double scale) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  const c = size / 2;
  const dot = 56.0;
  const bands = <List<double>>[ // [inner, outer], unscaled units
    [304, 344],
    [208, 248],
    [112, 152],
  ];

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x + 0.5 - c;
      final dy = y + 0.5 - c;
      final d = sqrt(dx * dx + dy * dy) / scale; // unscaled distance
      var a = _disk(d, dot);
      for (final b in bands) {
        a = max(a, _ring(d, b[0], b[1]));
      }
      im.setPixelRgba(x, y, 255, 255, 255, (a * 255).round());
    }
  }
  return im;
}

void _write(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote $path');
}

void main() {
  final bg = _gradient();

  final iconFull = img.Image.from(bg);
  img.compositeImage(iconFull, _mark(1.0)); // mark over gradient

  _write('assets/icon/icon.png', iconFull);
  _write('assets/icon/icon_background.png', bg);
  _write('assets/icon/icon_foreground.png', _mark(0.82)); // padded for safe zone
}
