import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/account/account_controller.dart';
import 'package:my_note/features/account/cloud_onboarding.dart';
import 'package:my_note/features/account/cloud_sync.dart';
import 'package:my_note/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending full snapshot and network policy survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = AppStore.seeded();
    final account = await AccountController.load(firebaseAvailable: false);
    final firstNetwork = FakeNetworkMonitor(SyncConnectionKind.offline);
    final gateway = FakeSyncGateway();
    final first = await CloudSyncController.load(
      store: store,
      account: account,
      preferences: preferences,
      network: firstNetwork,
      gateway: gateway,
      currentUid: () => 'user-1',
      canSynchronize: () => true,
    );
    await first.activateForAccount('user-1', cloudSyncToken: 'token-1');
    await first.setNetworkPolicy(SyncNetworkPolicy.manualOnly);

    store.addTodo('offline todo');
    await first.flushPersistence();

    expect(first.pendingCount, 1);
    expect(first.status, CloudSyncStatus.waitingForConnection);
    expect(gateway.snapshots, isEmpty);
    first.dispose();

    final secondNetwork = FakeNetworkMonitor(SyncConnectionKind.wifi);
    final second = await CloudSyncController.load(
      store: store,
      account: account,
      preferences: preferences,
      network: secondNetwork,
      gateway: gateway,
      currentUid: () => 'user-1',
      canSynchronize: () => true,
    );

    expect(second.pendingCount, 1);
    expect(second.networkPolicy, SyncNetworkPolicy.manualOnly);
    expect(second.status, CloudSyncStatus.waitingForConnection);
    await second.setNetworkPolicy(SyncNetworkPolicy.wifiOnly);
    await waitFor(() => second.pendingCount == 0);

    expect(second.status, CloudSyncStatus.synchronized);
    expect(
      gateway.snapshots.single.records.values.single.data['title'],
      'offline todo',
    );
    second.dispose();
    account.dispose();
    store.dispose();
  });

  test('cloud token mismatch keeps the local job in conflict state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore.seeded();
    final account = await AccountController.load(firebaseAvailable: false);
    final gateway = FakeSyncGateway(conflict: true);
    final sync = await CloudSyncController.load(
      store: store,
      account: account,
      network: FakeNetworkMonitor(SyncConnectionKind.wifi),
      gateway: gateway,
      currentUid: () => 'user-2',
      canSynchronize: () => true,
    );
    await sync.activateForAccount('user-2', cloudSyncToken: 'old-token');

    store.addTodo('conflicting todo');
    await waitFor(() => sync.status == CloudSyncStatus.conflict);

    expect(sync.pendingCount, 1);
    expect(gateway.expectedTokens.single, 'old-token');
    sync.dispose();
    account.dispose();
    store.dispose();
  });

  test(
    'failed sync retains local work and retry clears it after success',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore.seeded();
      final account = await AccountController.load(firebaseAvailable: false);
      final gateway = FakeSyncGateway(failuresBeforeSuccess: 1);
      final sync = await CloudSyncController.load(
        store: store,
        account: account,
        network: FakeNetworkMonitor(SyncConnectionKind.wifi),
        gateway: gateway,
        currentUid: () => 'user-3',
        canSynchronize: () => true,
      );
      await sync.activateForAccount('user-3', cloudSyncToken: 'token-3');

      store.addTodo('retry todo');
      await waitFor(() => sync.status == CloudSyncStatus.failed);
      expect(sync.pendingCount, 1);

      await sync.retry();
      expect(sync.pendingCount, 0);
      expect(sync.status, CloudSyncStatus.synchronized);
      sync.dispose();
      account.dispose();
      store.dispose();
    },
  );

  test(
    'remote token change downloads data without echoing a new job',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore.seeded();
      final account = await AccountController.load(firebaseAvailable: false);
      final gateway = FakeSyncGateway(
        pullState: CloudSpaceState(
          syncToken: 'remote-token',
          snapshot: CloudSpaceSnapshot(
            records: {
              'todos:remote': CloudRecord(
                collection: 'todos',
                id: 'remote',
                data: {'id': 'remote', 'title': 'remote todo', 'done': false},
              ),
            },
            settings: const {},
          ),
        ),
      );
      final sync = await CloudSyncController.load(
        store: store,
        account: account,
        network: FakeNetworkMonitor(SyncConnectionKind.wifi),
        gateway: gateway,
        currentUid: () => 'user-4',
        canSynchronize: () => true,
      );
      await sync.activateForAccount('user-4', cloudSyncToken: 'local-token');

      gateway.emitToken('remote-token');
      await waitFor(() => store.todos.any((todo) => todo.id == 'remote'));

      expect(store.todos.single.title, 'remote todo');
      expect(sync.pendingCount, 0);
      expect(sync.status, CloudSyncStatus.synchronized);
      sync.dispose();
      account.dispose();
      store.dispose();
    },
  );
}

Future<void> waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for asynchronous sync state.');
}

class FakeNetworkMonitor implements SyncNetworkMonitor {
  FakeNetworkMonitor(this._current);

  final controller = StreamController<SyncConnectionKind>.broadcast();
  SyncConnectionKind _current;

  @override
  SyncConnectionKind get current => _current;

  @override
  Stream<SyncConnectionKind> get changes => controller.stream;

  void setConnection(SyncConnectionKind value) {
    _current = value;
    controller.add(value);
  }

  @override
  Future<void> refresh() async {}

  @override
  void dispose() {
    unawaited(controller.close());
  }
}

class FakeSyncGateway implements CloudSyncGateway {
  FakeSyncGateway({
    this.conflict = false,
    this.failuresBeforeSuccess = 0,
    this.pullState,
  });

  final bool conflict;
  int failuresBeforeSuccess;
  CloudSpaceState? pullState;
  final snapshots = <CloudSpaceSnapshot>[];
  final expectedTokens = <String?>[];
  final tokenChanges = StreamController<String?>.broadcast();

  void emitToken(String? token) => tokenChanges.add(token);

  @override
  Future<CloudSpaceState> pull(String uid) async =>
      pullState ??
      const CloudSpaceState(
        snapshot: CloudSpaceSnapshot(records: {}, settings: {}),
        syncToken: null,
      );

  @override
  Future<CloudPushResult> push(
    String uid,
    CloudSpaceSnapshot snapshot, {
    required String? expectedSyncToken,
  }) async {
    snapshots.add(snapshot);
    expectedTokens.add(expectedSyncToken);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('temporary failure');
    }
    if (conflict) return const CloudPushResult.conflict();
    return const CloudPushResult.success('next-token');
  }

  @override
  Stream<String?> watchSyncToken(String uid) => tokenChanges.stream;
}
