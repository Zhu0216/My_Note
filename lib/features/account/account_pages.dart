import 'package:flutter/material.dart';

import 'account_controller.dart';

class AccountEntryGate extends StatelessWidget {
  const AccountEntryGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.maybeOf(context);
    if (account == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        if (account.entryChoice != AccountEntryChoice.undecided) return child;
        return AccountEntryPage(account: account);
      },
    );
  }
}

class AccountStatusButton extends StatelessWidget {
  const AccountStatusButton({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.maybeOf(context);
    if (account == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) => IconButton(
        tooltip: account.isSignedIn ? '帳號與同步' : '登入並同步',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                account.isSignedIn ? const AccountPage() : const SignInPage(),
          ),
        ),
        icon: Icon(
          account.canSynchronize
              ? Icons.cloud_done_outlined
              : account.isSignedIn
              ? Icons.cloud_sync_outlined
              : Icons.account_circle_outlined,
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('帳號與同步')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [AccountSettingsCard()],
      ),
    ),
  );
}

class AccountEntryPage extends StatelessWidget {
  const AccountEntryPage({super.key, required this.account});

  final AccountController account;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'My Note',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '選擇是否登入同步。本機資料不需要帳號，也不會自動上傳。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: account.firebaseAvailable
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignInPage(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('登入並同步'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: account.busy ? null : account.continueLocally,
                    icon: const Icon(Icons.phone_android_outlined),
                    label: const Text('直接使用本機資料'),
                  ),
                  if (!account.firebaseAvailable) ...[
                    const SizedBox(height: 12),
                    Text(
                      '同步服務目前無法連線，仍可正常使用本機資料。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool createAccount = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final account = AccountScope.of(context);
    final success = createAccount
        ? await account.createEmailAccount(
            emailController.text,
            passwordController.text,
          )
        : await account.signInWithEmail(
            emailController.text,
            passwordController.text,
          );
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> resetPassword() async {
    final account = AccountScope.of(context);
    if (emailController.text.trim().isEmpty) return;
    final success = await account.sendPasswordReset(emailController.text);
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密碼重設信已寄出')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(createAccount ? '建立帳號' : '登入並同步')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: account.busy
                            ? null
                            : () async {
                                if (await account.signInWithGoogle() &&
                                    context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('使用 Google 繼續'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('或使用電子郵件'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: '電子郵件',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofillHints: [
                          createAccount
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: '密碼',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword ? '顯示密碼' : '隱藏密碼',
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (account.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          account.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: account.busy ? null : submit,
                        child: account.busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(createAccount ? '建立帳號' : '登入'),
                      ),
                      TextButton(
                        onPressed: account.busy
                            ? null
                            : () => setState(
                                () => createAccount = !createAccount,
                              ),
                        child: Text(createAccount ? '已有帳號？登入' : '沒有帳號？建立帳號'),
                      ),
                      if (!createAccount)
                        TextButton(
                          onPressed: account.busy ? null : resetPassword,
                          child: const Text('忘記密碼'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountSettingsCard extends StatelessWidget {
  const AccountSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        final user = account.user;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    user == null ? Icons.cloud_off_outlined : Icons.cloud_done,
                  ),
                  title: Text(user?.email ?? '本機使用中'),
                  subtitle: Text(
                    user == null
                        ? '資料只儲存在這部裝置'
                        : account.isEmailVerified
                        ? '帳號已驗證，可開始同步設定'
                        : '請先驗證電子郵件；驗證前不會同步',
                  ),
                ),
                if (account.errorMessage != null)
                  Text(
                    account.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (user == null)
                  FilledButton.icon(
                    onPressed: account.firebaseAvailable
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignInPage(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.login),
                    label: const Text('登入並同步'),
                  )
                else ...[
                  if (!account.isEmailVerified)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: account.busy
                              ? null
                              : account.sendEmailVerification,
                          child: const Text('重寄驗證信'),
                        ),
                        OutlinedButton(
                          onPressed: account.busy ? null : account.reloadUser,
                          child: const Text('我已完成驗證'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: account.busy ? null : account.linkGoogle,
                    icon: const Icon(Icons.add_link),
                    label: const Text('連結 Google 登入'),
                  ),
                  OutlinedButton.icon(
                    onPressed: account.busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LinkEmailPage(),
                            ),
                          ),
                    icon: const Icon(Icons.alternate_email),
                    label: const Text('連結電子郵件密碼'),
                  ),
                  TextButton.icon(
                    onPressed: account.busy
                        ? null
                        : () => account.signOut(keepLocalChoice: true),
                    icon: const Icon(Icons.logout),
                    label: const Text('登出並保留本機資料'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: account.busy
                        ? null
                        : () => _confirmDelete(context, account),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('刪除帳號'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AccountController account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除帳號？'),
        content: const Text('這會刪除登入帳號。同步資料的刪除範圍會在同步功能啟用前再次確認。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除帳號'),
          ),
        ],
      ),
    );
    if (confirmed == true) await account.deleteAccount();
  }
}

class LinkEmailPage extends StatefulWidget {
  const LinkEmailPage({super.key});

  @override
  State<LinkEmailPage> createState() => _LinkEmailPageState();
}

class _LinkEmailPageState extends State<LinkEmailPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('連結電子郵件密碼')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '電子郵件'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密碼'),
            ),
            if (account.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                account.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: account.busy
                  ? null
                  : () async {
                      if (await account.linkEmailPassword(
                            emailController.text,
                            passwordController.text,
                          ) &&
                          context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('連結並寄送驗證信'),
            ),
          ],
        ),
      ),
    );
  }
}
