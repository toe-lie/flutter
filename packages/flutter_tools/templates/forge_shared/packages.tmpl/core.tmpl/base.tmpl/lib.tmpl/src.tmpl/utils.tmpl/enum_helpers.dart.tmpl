/// Returns the key associated with value [source] from [enumValues], if one
/// exists.
///
/// If [unknownValue] is not `null` and [source] is not a value in [enumValues],
/// [unknownValue] is returned. Otherwise, an [ArgumentError] is thrown.
///
/// If [source] is `null`, an [ArgumentError] is thrown.
///
/// Adopted from `package:json_annotation`.
K decodeEnum<K extends Enum, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  for (var entry in enumValues.entries) {
    if (entry.value == source) {
      return entry.key;
    }
  }

  if (unknownValue == null) {
    throw ArgumentError(
      '`$source` is not one of the supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return unknownValue;
}

V encodeEnum<K extends Enum, V>(
  Map<K, V> enumValues,
  K key,
) {
  return enumValues[key] ?? (throw ArgumentError('`Unsupported enum: $key`'));
}
