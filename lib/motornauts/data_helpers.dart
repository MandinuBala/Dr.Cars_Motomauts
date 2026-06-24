List<Map<String, dynamic>> objectList(
  Object? data, {
  List<String> keys = const [],
}) {
  if (data is List) {
    return data.whereType<Map>().map(_stringMap).toList();
  }
  if (data is Map) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value.whereType<Map>().map(_stringMap).toList();
      }
    }
    final items = data['items'] ?? data['data'] ?? data['results'];
    if (items is List) {
      return items.whereType<Map>().map(_stringMap).toList();
    }
  }
  return const [];
}

Map<String, dynamic> objectMap(Object? data) {
  if (data is Map) {
    return _stringMap(data);
  }
  return const {};
}

String valueText(
  Map<String, dynamic> object,
  List<String> keys, {
  String fallback = '-',
}) {
  for (final key in keys) {
    final value = object[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return fallback;
}

String? objectId(Map<String, dynamic> object, List<String> keys) {
  final text = valueText(object, keys, fallback: '');
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _stringMap(Map value) {
  return value.map((key, dynamic value) => MapEntry(key.toString(), value));
}
