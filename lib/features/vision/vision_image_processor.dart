
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum VisionFilterType { none, blur, sharpen, edgeDetection }

enum VisionPresetStyle {
  original,
  warm,
  cool,
  vintage,
  punch,
  sharp,
  drama,
  monochrome,
}

class VisionPresetConfig {
  const VisionPresetConfig({
    required this.applyContrast,
    required this.filterType,
    required this.filterIntensity,
    required this.contrast,
    required this.brightness,
    required this.saturation,
    required this.forceGrayscale,
  });

  final bool applyContrast;
  final VisionFilterType filterType;
  final double filterIntensity;
  final double contrast;
  final double brightness;
  final double saturation;
  final bool forceGrayscale;
}

VisionPresetConfig visionPresetConfig(VisionPresetStyle style) {
  switch (style) {
    case VisionPresetStyle.warm:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.none,
        filterIntensity: 0.55,
        contrast: 1.08,
        brightness: 0.03,
        saturation: 1.12,
        forceGrayscale: false,
      );
    case VisionPresetStyle.cool:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.none,
        filterIntensity: 0.55,
        contrast: 1.06,
        brightness: 0.0,
        saturation: 1.05,
        forceGrayscale: false,
      );
    case VisionPresetStyle.vintage:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.none,
        filterIntensity: 0.75,
        contrast: 0.94,
        brightness: 0.02,
        saturation: 0.88,
        forceGrayscale: false,
      );
    case VisionPresetStyle.punch:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.none,
        filterIntensity: 0.8,
        contrast: 1.18,
        brightness: 0.0,
        saturation: 1.24,
        forceGrayscale: false,
      );
    case VisionPresetStyle.sharp:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.sharpen,
        filterIntensity: 0.95,
        contrast: 1.12,
        brightness: 0.0,
        saturation: 1.06,
        forceGrayscale: false,
      );
    case VisionPresetStyle.drama:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.edgeDetection,
        filterIntensity: 0.7,
        contrast: 1.24,
        brightness: -0.01,
        saturation: 1.08,
        forceGrayscale: false,
      );
    case VisionPresetStyle.monochrome:
      return const VisionPresetConfig(
        applyContrast: true,
        filterType: VisionFilterType.none,
        filterIntensity: 1.0,
        contrast: 1.05,
        brightness: 0.0,
        saturation: 0.0,
        forceGrayscale: true,
      );
    case VisionPresetStyle.original:
      return const VisionPresetConfig(
        applyContrast: false,
        filterType: VisionFilterType.none,
        filterIntensity: 0.0,
        contrast: 1.0,
        brightness: 0.0,
        saturation: 1.0,
        forceGrayscale: false,
      );
  }
}

class VisionProcessingResult {
  const VisionProcessingResult({
    required this.imageBytes,
    required this.histogramBins,
  });

  final Uint8List imageBytes;
  final List<int> histogramBins;
}

class VisionImageProcessor {
  static Future<VisionProcessingResult> process({
    required Uint8List sourceBytes,
    required bool applyContrast,
    required VisionFilterType filterType,
    required double filterIntensity,
    required VisionPresetStyle presetStyle,
    double customContrast = 1.0,
    double customBrightness = 0.0,
    double customSaturation = 1.0,
    int? maxDimension,
    bool includeHistogram = true,
  }) {
    return compute(
      _processInIsolate,
      <String, Object>{
        'bytes': sourceBytes,
        'applyContrast': applyContrast,
        'filter': filterType.name,
        'intensity': filterIntensity,
        'preset': presetStyle.name,
        'customContrast': customContrast,
        'customBrightness': customBrightness,
        'customSaturation': customSaturation,
        'maxDimension': maxDimension ?? 0,
        'includeHistogram': includeHistogram,
      },
    );
  }
}

VisionProcessingResult _processInIsolate(Map<String, Object> payload) {
  final bytes = payload['bytes'] as Uint8List;
  final applyContrast = payload['applyContrast'] as bool;
  final filterName = payload['filter'] as String;
  final intensity = (payload['intensity'] as num).toDouble().clamp(0.0, 1.0);
  final presetName = payload['preset'] as String;
  final customContrast = (payload['customContrast'] as num?)?.toDouble() ?? 1.0;
  final customBrightness =
      (payload['customBrightness'] as num?)?.toDouble() ?? 0.0;
  final customSaturation =
      (payload['customSaturation'] as num?)?.toDouble() ?? 1.0;
  final maxDimension = (payload['maxDimension'] as num?)?.toInt() ?? 0;
  final includeHistogram = payload['includeHistogram'] as bool? ?? true;
  final presetStyle = VisionPresetStyle.values.firstWhere(
    (value) => value.name == presetName,
    orElse: () => VisionPresetStyle.original,
  );

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode captured image.');
  }

  final original = decoded.clone();
  final workingSource =
      maxDimension > 0 ? _downscaleIfNeeded(decoded, maxDimension) : decoded;
  final sourceForBlend =
      maxDimension > 0 ? _downscaleIfNeeded(original, maxDimension) : original;
  img.Image working = workingSource.clone();

  final presetConfig = visionPresetConfig(presetStyle);

  final contrastMultiplier =
      (applyContrast && presetStyle == VisionPresetStyle.original) ? 1.25 : 1.0;
  final brightnessOffset =
      (applyContrast && presetStyle == VisionPresetStyle.original) ? 0.02 : 0.0;
  final saturationMultiplier =
      (applyContrast && presetStyle == VisionPresetStyle.original) ? 1.04 : 1.0;

  final finalContrast =
      (presetConfig.contrast * contrastMultiplier * customContrast)
          .clamp(0.2, 3.0);
  final finalBrightness =
      (presetConfig.brightness + brightnessOffset + customBrightness)
          .clamp(-0.45, 0.45);
  final brightnessMultiplier = (1.0 + finalBrightness).clamp(0.0, 2.0);
  final finalSaturation =
      (presetConfig.saturation * saturationMultiplier * customSaturation)
          .clamp(0.0, 3.0);

  if (presetConfig.forceGrayscale) {
    working = img.grayscale(working);
  } else {
    working = img.adjustColor(
      working,
      contrast: finalContrast,
      // image.adjustColor expects brightness multiplier (1.0 = unchanged).
      brightness: brightnessMultiplier,
      saturation: finalSaturation,
    );
  }

  final effectiveFilter = presetConfig.filterType == VisionFilterType.none
      ? filterName
      : presetConfig.filterType.name;
  final effectiveIntensity = presetConfig.filterIntensity > 0
      ? presetConfig.filterIntensity
      : intensity;

  switch (effectiveFilter) {
    case 'blur':
      working = img.gaussianBlur(working, radius: 4);
      break;
    case 'sharpen':
      working = img.convolution(
        working,
        filter: <double>[
          0,
          -1,
          0,
          -1,
          5,
          -1,
          0,
          -1,
          0,
        ],
      );
      break;
    case 'edgeDetection':
      working = img.convolution(
        working,
        filter: <double>[
          -1,
          -1,
          -1,
          -1,
          8,
          -1,
          -1,
          -1,
          -1,
        ],
      );
      break;
    case 'none':
    default:
      break;
  }

  if (effectiveIntensity < 1.0) {
    working = _blendWithOriginal(
      original: sourceForBlend,
      filtered: working,
      amount: effectiveIntensity,
    );
  }

  final histogramBins =
      includeHistogram ? _buildHistogram(working, bins: 64) : const <int>[];
  final encoded = Uint8List.fromList(img.encodeJpg(working, quality: 92));

  return VisionProcessingResult(
    imageBytes: encoded,
    histogramBins: histogramBins,
  );
}

img.Image _downscaleIfNeeded(img.Image image, int maxDimension) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxDimension) {
    return image.clone();
  }

  if (image.width >= image.height) {
    return img.copyResize(
      image,
      width: maxDimension,
      interpolation: img.Interpolation.linear,
    );
  }

  return img.copyResize(
    image,
    height: maxDimension,
    interpolation: img.Interpolation.linear,
  );
}

img.Image _blendWithOriginal({
  required img.Image original,
  required img.Image filtered,
  required double amount,
}) {
  final blended = original.clone();
  final inverse = 1.0 - amount;

  for (var y = 0; y < original.height; y++) {
    for (var x = 0; x < original.width; x++) {
      final base = original.getPixel(x, y);
      final fx = filtered.getPixel(x, y);
      final out = blended.getPixel(x, y);

      out
        ..r = (base.r * inverse + fx.r * amount)
        ..g = (base.g * inverse + fx.g * amount)
        ..b = (base.b * inverse + fx.b * amount)
        ..a = (base.a * inverse + fx.a * amount);
    }
  }

  return blended;
}

List<int> _buildHistogram(img.Image image, {required int bins}) {
  final histogram = List<int>.filled(bins, 0);
  final bucketSize = 256 / bins;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = _channelToByte(pixel.r);
      final g = _channelToByte(pixel.g);
      final b = _channelToByte(pixel.b);
      final luminance = (((r * 299) + (g * 587) + (b * 114)) / 1000).round();
      final index = (luminance / bucketSize).floor().clamp(0, bins - 1);
      histogram[index]++;
    }
  }

  return histogram;
}

int _channelToByte(num channel) {
  final value = channel.toDouble();
  final normalized = value <= 1.0 ? value * 255.0 : value;
  return normalized.round().clamp(0, 255);
}
