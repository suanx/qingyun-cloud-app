/// 后端响应字段容错解析。
///
/// 数值字段可能因后端版本差异返回字符串或异常类型；这里统一按缺省值处理，
/// 避免裸 `as num?` 在字段类型变化时直接抛 CastError 导致页面崩溃。
abstract final class JsonUtils {
  static int asInt(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double asDouble(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
