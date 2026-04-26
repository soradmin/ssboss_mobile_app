// lib/core/result.dart
/// Универсальный тип для возврата результата операции: успех (Ok) или ошибка (Err)
abstract class Result<T> {
  const Result();
  
  /// Pattern matching для обработки результата
  R when<R>({
    required R Function(T value) ok,
    required R Function(String message) err,
  }) {
    if (this is Ok<T>) {
      return ok((this as Ok<T>).value);
    } else if (this is Err<T>) {
      return err((this as Err<T>).message);
    }
    throw StateError('Unknown Result type');
  }
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