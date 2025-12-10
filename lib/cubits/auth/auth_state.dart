abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthAuthenticated extends AuthState {
  final String serverUrl;
  final String accessToken;
  final String userId;

  AuthAuthenticated({
    required this.serverUrl,
    required this.accessToken,
    required this.userId,
  });
  
  String getImageUrl(String itemId, String? tag, {String type = "Primary"}) {
    if (tag == null) return "";
    return "$serverUrl/Items/$itemId/Images/$type?tag=$tag&maxWidth=400";
  }
}
