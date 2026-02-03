class AuthController {
  static final AuthController instance = AuthController._internal();
  
  factory AuthController() {
    return instance;
  }
  
  AuthController._internal();

  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;

  // Getters
  String? get verificationId => _verificationId;
  int? get resendToken => _resendToken;
  String? get phoneNumber => _phoneNumber;

  // Setters
  void setVerificationId(String id) {
    _verificationId = id;
  }

  void setResendToken(int? token) {
    _resendToken = token;
  }

  void setPhoneNumber(String number) {
    _phoneNumber = number;
  }

  void clear() {
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
  }
}
