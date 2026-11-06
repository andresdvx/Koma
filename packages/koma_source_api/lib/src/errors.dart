/// Errores tipados del contrato; el bridge nativo los traduce por `code`.
sealed class KomaError implements Exception {
  const KomaError(this.message);
  final String message;

  String get code;

  @override
  String toString() => '$code: $message';

  factory KomaError.fromCode(String code, [String message = '']) =>
      switch (code) {
        'ExtensionNotFound' => ExtensionNotFound(message),
        'ExtensionNotTrusted' => ExtensionNotTrusted(message),
        'ExtensionIncompatible' => ExtensionIncompatible(message),
        'SourceNotFound' => SourceNotFound(message),
        'NetworkError' => NetworkError(message),
        'AuthenticationRequired' => AuthenticationRequired(message),
        'RateLimited' => RateLimited(message),
        'ContentUnavailable' => ContentUnavailable(message),
        'RuntimeUnavailable' => RuntimeUnavailable(message),
        _ => UnknownError(message),
      };
}

class ExtensionNotFound extends KomaError {
  const ExtensionNotFound([super.message = '']);
  @override
  String get code => 'ExtensionNotFound';
}

class ExtensionNotTrusted extends KomaError {
  const ExtensionNotTrusted([super.message = '']);
  @override
  String get code => 'ExtensionNotTrusted';
}

class ExtensionIncompatible extends KomaError {
  const ExtensionIncompatible([super.message = '']);
  @override
  String get code => 'ExtensionIncompatible';
}

class SourceNotFound extends KomaError {
  const SourceNotFound([super.message = '']);
  @override
  String get code => 'SourceNotFound';
}

class NetworkError extends KomaError {
  const NetworkError([super.message = '']);
  @override
  String get code => 'NetworkError';
}

class AuthenticationRequired extends KomaError {
  const AuthenticationRequired([super.message = '']);
  @override
  String get code => 'AuthenticationRequired';
}

class RateLimited extends KomaError {
  const RateLimited([super.message = '']);
  @override
  String get code => 'RateLimited';
}

class ContentUnavailable extends KomaError {
  const ContentUnavailable([super.message = '']);
  @override
  String get code => 'ContentUnavailable';
}

class RuntimeUnavailable extends KomaError {
  const RuntimeUnavailable([super.message = '']);
  @override
  String get code => 'RuntimeUnavailable';
}

class UnknownError extends KomaError {
  const UnknownError([super.message = '']);
  @override
  String get code => 'UnknownError';
}
