import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountEntryChoice { undecided, localOnly, signedIn }

class AccountController extends ChangeNotifier {
  AccountController._(this._preferences, this._auth, this.firebaseAvailable);

  static const _localChoiceKey = 'account.local_only_entry';

  final SharedPreferences _preferences;
  final FirebaseAuth? _auth;
  final bool firebaseAvailable;
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _busy = false;
  String? _errorMessage;

  static Future<AccountController> load({
    required bool firebaseAvailable,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final auth = firebaseAvailable ? FirebaseAuth.instance : null;
    final controller = AccountController._(
      preferences,
      auth,
      firebaseAvailable,
    );
    controller._user = auth?.currentUser;
    if (auth != null) {
      controller._authSubscription = auth.userChanges().listen((user) {
        controller._user = user;
        controller.notifyListeners();
      });
    }
    return controller;
  }

  User? get user => _user;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _user != null;
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get canSynchronize => isSignedIn && isEmailVerified;

  AccountEntryChoice get entryChoice {
    if (isSignedIn) return AccountEntryChoice.signedIn;
    return _preferences.getBool(_localChoiceKey) == true
        ? AccountEntryChoice.localOnly
        : AccountEntryChoice.undecided;
  }

  Future<void> continueLocally() async {
    await _preferences.setBool(_localChoiceKey, true);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> showEntryChoiceNextLaunch() async {
    await _preferences.remove(_localChoiceKey);
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) => _run(() async {
    await _requireAuth().signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _preferences.remove(_localChoiceKey);
  });

  Future<bool> createEmailAccount(String email, String password) =>
      _run(() async {
        final credential = await _requireAuth().createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user?.sendEmailVerification();
        await _preferences.remove(_localChoiceKey);
      });

  Future<bool> sendPasswordReset(String email) => _run(() async {
    await _requireAuth().sendPasswordResetEmail(email: email.trim());
  });

  Future<bool> sendEmailVerification() => _run(() async {
    await _user?.sendEmailVerification();
  });

  Future<bool> reloadUser() => _run(() async {
    await _user?.reload();
    _user = _requireAuth().currentUser;
  });

  Future<bool> signInWithGoogle() => _run(() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _requireAuth().signInWithPopup(provider);
    } else {
      await _requireAuth().signInWithProvider(provider);
    }
    await _preferences.remove(_localChoiceKey);
  });

  Future<bool> linkGoogle() => _run(() async {
    final currentUser = _requireUser();
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await currentUser.linkWithPopup(provider);
    } else {
      await currentUser.linkWithProvider(provider);
    }
  });

  Future<bool> linkEmailPassword(String email, String password) =>
      _run(() async {
        await _requireUser().linkWithCredential(
          EmailAuthProvider.credential(email: email.trim(), password: password),
        );
        await _user?.sendEmailVerification();
      });

  Future<bool> signOut({required bool keepLocalChoice}) => _run(() async {
    await _requireAuth().signOut();
    if (keepLocalChoice) {
      await _preferences.setBool(_localChoiceKey, true);
    } else {
      await _preferences.remove(_localChoiceKey);
    }
  });

  Future<bool> deleteAccount() => _run(() async {
    await _requireUser().delete();
    await _preferences.remove(_localChoiceKey);
  });

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) throw StateError('Firebase 尚未啟用');
    return auth;
  }

  User _requireUser() {
    final currentUser = _user;
    if (currentUser == null) throw StateError('尚未登入');
    return currentUser;
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
      _user = _auth?.currentUser;
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message.toString()
          : '操作失敗，請稍後再試';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'invalid-email' => '電子郵件格式不正確',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => '電子郵件或密碼不正確',
    'email-already-in-use' => '此電子郵件已被使用',
    'weak-password' => '密碼至少需要 6 個字元',
    'provider-already-linked' => '這個登入方式已經連結',
    'credential-already-in-use' ||
    'account-exists-with-different-credential' => '此登入方式已屬於另一個帳號，請先登入該帳號再進行連結',
    'requires-recent-login' => '為保護帳號，請重新登入後再執行此操作',
    'network-request-failed' => '網路連線失敗，請稍後再試',
    'popup-closed-by-user' || 'web-context-cancelled' => '已取消登入',
    _ => error.message ?? '帳號操作失敗',
  };

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    super.key,
    required AccountController controller,
    required super.child,
  }) : super(notifier: controller);

  static AccountController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope != null, 'AccountScope is missing.');
    return scope!.notifier!;
  }

  static AccountController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
