import 'package:latlong2/latlong.dart';

class PolylineDecoder {
  PolylineDecoder._();

  static List<LatLng> decode(String encoded, {int precision = 6}) {
    final coordinates = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    final factor = pow10(precision);

    while (index < encoded.length) {
      final resultLat = _decodeValue(encoded, index);
      index = resultLat.nextIndex;
      lat += resultLat.value;

      final resultLng = _decodeValue(encoded, index);
      index = resultLng.nextIndex;
      lng += resultLng.value;

      coordinates.add(LatLng(lat / factor, lng / factor));
    }

    return coordinates;
  }

  static _DecodeResult _decodeValue(String encoded, int startIndex) {
    var result = 0;
    var shift = 0;
    var index = startIndex;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _DecodeResult(value: delta, nextIndex: index);
  }
}

class _DecodeResult {
  final int value;
  final int nextIndex;

  const _DecodeResult({required this.value, required this.nextIndex});
}

int pow10(int exponent) {
  var value = 1.0;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value.toInt();
}
