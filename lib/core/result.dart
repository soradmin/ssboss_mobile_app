// lib/core/result.dart
/// Универсальный тип для возврата результата операции: успех (Ok) или ошибка (Err)
abstract class Result<T> {
  const Result();
}

/// Успешный результат, содержащий значение типа T
class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value) : super();
}

/// Результат с ошибкой, содержащий сообщение об ошибке
class Err<T> extends Result<T> {
  final String message;

  const Err(this.message) : super();
}