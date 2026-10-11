import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/my_note_data.dart';
import 'account_controller.dart';
import 'cloud_assets.dart';
import 'cloud_onboarding.dart';

enum CloudSyncStatus {
  synchronized,
  waitingForConnection,
  synchronizing,
  conflict,
  failed,
}

enum SyncNetworkPolicy { wifiOnly, anyNetwork, manualOnly }

enum SyncConnectionKind { offline, wifi, mobile, other }

class CloudSyncJob {
  const CloudSyncJob({
    required this.id,
    required this.uid,
    required this.revision,
    required this.action,
    required this.createdAt,
    required this.data,
  });

  factory CloudSyncJob.fromJson(Map<String, dynamic> value) => CloudSyncJob(
    id: readString(value['id']),
    uid: readString(value['uid']),
    revision: readInt(value['revision']),
    action: readString(value['action'], fallback: 'state.update'),
    createdAt: readDate(value['createdAt']),
    data: cloneJsonMap(value['data']),
  );

  final String id;
  final String uid;
  final int revision;
  final String action;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'revision': revision,
    'action': action,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
  };
}

abstract interface class CloudSyncGateway {
  Future<CloudPushResult> push(
    String uid,
    CloudSpaceSnapshot snapshot, {
    required String? expectedSyncToken,
  });

  Future<CloudSpaceState> pull(String uid);
  Stream<String?> watchSyncToken(String uid);
}

class FirestoreCloudSyncGateway implements CloudSyncGateway {
  FirestoreCloudSyncGateway(
    this._store, {
    CloudSpaceRepository? repository,
    CloudAssetTransfer? assets,
  }) : _repository = repository ?? CloudSpaceRepository(),
       _assets = assets ?? CloudAssetTransfer();

  final AppStore _store;
  final CloudSpaceRepository _repository;
  final CloudAssetTransfer _assets;

  @override
  Future<CloudPushResult> push(
    String uid,
    CloudSpaceSnapshot snapshot, {
    required String? expectedSyncToken,
  }) async {
    final cloudSnapshot = await _assets.uploadSnapshot(uid, snapshot, _store);
    return _repository.pushIfUnchanged(
      uid,
      cloudSnapshot,
      expectedSyncToken: expectedSyncToken,
    );
  }

  @override
  Future<CloudSpaceState> pull(String uid) async {
    final state = await _repository.readState(uid);
    return CloudSpaceState(
      snapshot: await _assets.downloadSnapshot(state.snapshot),
      syncToken: state.syncToken,
    );
  }

  @override
  Stream<String?> watchSyncToken(String uid) => _repository.watchSyncToken(uid);
}

abstract interface class SyncNetworkMonitor {
  SyncConnectionKind get current;
  Stream<SyncConnectionKind> get changes;
  Future<void> refresh();
  void dispose();
}

class ConnectivitySyncNetworkMonitor implements SyncNetworkMonitor {
  ConnectivitySyncNetworkMonitor() {
    _subscription = Connectivity().onConnectivityChanged.listen(_update);
    unawaited(refresh());
  }

  final _controller = StreamController<SyncConnectionKind>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  SyncConnectionKind _current = SyncConnectionKind.offline;

  @override
  SyncConnectionKind get current => _current;

  @override
  Stream<SyncConnectionKind> get changes => _controller.stream;

  @override
  Future<void> refresh() async {
    _update(await Connectivity().checkConnectivity());
  }

  void _update(List<ConnectivityResult> values) {
    final next = _mapConnectivity(values);
    if (next == _current) return;
    _current = next;
    _controller.add(next);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller.close());
  }
}

SyncConnectionKind _mapConnectivity(List<ConnectivityResult> values) {
  if (values.isEmpty ||
      values.every((value) => value == ConnectivityResult.none)) {
    return SyncConnectionKind.offline;
  }
  if (values.contains(ConnectivityResult.wifi) ||
      values.contains(ConnectivityResult.ethernet)) {
    return SyncConnectionKind.wifi;
  }
  if (values.contains(ConnectivityResult.mobile)) {
    return SyncConnectionKind.mobile;
  }
  return SyncConnectionKind.other;
}

class CloudSyncController extends ChangeNotifier {
  CloudSyncController._({
    required SharedPreferences preferences,
    required AppStore store,
    required AccountController account,
    required CloudSyncGateway gateway,
    required SyncNetworkMonitor network,
    required String? Function() currentUid,
    required bool Function() canSynchronize,
  }) : this._withFields(
         preferences,
         store,
         account,
         gateway,
         network,
         currentUid,
         canSynchronize,
       );

  CloudSyncController._withFields(
    this._preferences,
    this._store,
    this._account,
    this._gateway,
    this._network,
    this._currentUid,
    this._canSynchronize,
  );

  static const _storageKey = 'my_note.cloud_sync.v1';

  final SharedPreferences _preferences;
  final AppStore _store;
  final AccountController _account;
  final CloudSyncGateway _gateway;
  final SyncNetworkMonitor _network;
  final String? Function() _currentUid;
  final bool Function() _canSynchronize;
  StreamSubscription<SyncConnectionKind>? _networkSubscription;
  StreamSubscription<String?>? _remoteSubscription;
  String? _watchedUid;
  final List<CloudSyncJob> _queue = [];
  SyncNetworkPolicy _networkPolicy = SyncNetworkPolicy.wifiOnly;
  CloudSyncStatus _status = CloudSyncStatus.synchronized;
  String? _activeUid;
  String? _cloudSyncToken;
  String? _errorMessage;
  int _observedRevision = 0;
  bool _syncing = false;
  bool _applyingRemote = false;
  Future<void> _persistenceQueue = Future.value();

  static Future<CloudSyncController> load({
    required AppStore store,
    required AccountController account,
    CloudSyncGateway? gateway,
    SyncNetworkMonitor? network,
    SharedPreferences? preferences,
    String? Function()? currentUid,
    bool Function()? canSynchronize,
  }) async {
    final controller = CloudSyncController._(
      preferences: preferences ?? await SharedPreferences.getInstance(),
      store: store,
      account: account,
      gateway: gateway ?? FirestoreCloudSyncGateway(store),
      network: network ?? ConnectivitySyncNetworkMonitor(),
      currentUid: currentUid ?? () => account.user?.uid,
      canSynchronize: canSynchronize ?? () => account.canSynchronize,
    );
    controller._restore();
    controller._observedRevision = store.persistenceRevision;
    store.addListener(controller._onStoreChanged);
    account.addListener(controller._onAccountChanged);
    controller._networkSubscription = controller._network.changes.listen((_) {
      controller._refreshStatus();
      unawaited(controller._pump());
    });
    controller._refreshStatus();
    controller._refreshRemoteSubscription();
    unawaited(controller._pump());
    return controller;
  }

  CloudSyncStatus get status => _status;
  SyncNetworkPolicy get networkPolicy => _networkPolicy;
  SyncConnectionKind get connection => _network.current;
  int get pendingCount => _queue.length;
  String? get errorMessage => _errorMessage;
  bool get isActive => _activeUid != null;

  Future<void> activateForAccount(
    String uid, {
    required String cloudSyncToken,
  }) async {
    _activeUid = uid;
    _cloudSyncToken = cloudSyncToken;
    _queue.removeWhere((job) => job.uid == uid);
    _errorMessage = null;
    _status = CloudSyncStatus.synchronized;
    _observedRevision = _store.persistenceRevision;
    await _persist();
    _refreshRemoteSubscription();
    _refreshStatus();
  }

  Future<void> setNetworkPolicy(SyncNetworkPolicy value) async {
    _networkPolicy = value;
    await _persist();
    _refreshStatus();
    if (value != SyncNetworkPolicy.manualOnly) unawaited(_pump());
  }

  Future<void> synchronizeNow() => _pump(manual: true);

  Future<void> retry() async {
    _errorMessage = null;
    _refreshStatus();
    await _pump(manual: true);
  }

  void _restore() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final data = Map<String, dynamic>.from(value);
      _activeUid = readString(data['activeUid']).nullIfEmpty;
      _cloudSyncToken = readString(data['cloudSyncToken']).nullIfEmpty;
      _networkPolicy = readEnum(
        SyncNetworkPolicy.values,
        data['networkPolicy'],
        SyncNetworkPolicy.wifiOnly,
      );
      _queue
        ..clear()
        ..addAll(
          readMapList(data['queue'])
              .map(CloudSyncJob.fromJson)
              .where((job) => job.id.isNotEmpty && job.uid.isNotEmpty),
        );
    } catch (_) {
      _errorMessage = '同步佇列資料損毀，已保留本機資料';
    }
  }

  void _onStoreChanged() {
    final revision = _store.persistenceRevision;
    final uid = _activeUid;
    if (_applyingRemote) {
      _observedRevision = revision;
      return;
    }
    if (uid == null || revision == _observedRevision) return;
    _observedRevision = revision;
    final changedAt = _store.lastChangedAt ?? DateTime.now();
    final job = CloudSyncJob(
      id: '$uid-$revision-${changedAt.microsecondsSinceEpoch}',
      uid: uid,
      revision: revision,
      action: _store.lastChangeAction,
      createdAt: changedAt,
      data: cloneJsonMap(_store.toJson()),
    );
    _queue
      ..removeWhere((item) => item.uid == uid)
      ..add(job);
    _errorMessage = null;
    _schedulePersist();
    _refreshStatus();
    unawaited(_pump());
  }

  void _onAccountChanged() {
    _refreshRemoteSubscription();
    _refreshStatus();
    unawaited(_pump());
  }

  void _refreshRemoteSubscription() {
    final uid = _activeUid;
    final canWatch = uid != null && _canSynchronize() && _currentUid() == uid;
    if (!canWatch) {
      _watchedUid = null;
      unawaited(_remoteSubscription?.cancel());
      _remoteSubscription = null;
      return;
    }
    if (_watchedUid == uid && _remoteSubscription != null) return;
    unawaited(_remoteSubscription?.cancel());
    _watchedUid = uid;
    _remoteSubscription = _gateway.watchSyncToken(uid).listen((token) {
      if (token == null || token == _cloudSyncToken || _syncing) return;
      if (_queue.any((job) => job.uid == uid)) {
        _status = CloudSyncStatus.conflict;
        notifyListeners();
        return;
      }
      if (_networkPolicy != SyncNetworkPolicy.manualOnly) {
        unawaited(_pump());
      }
    });
  }

  bool _networkAllowsSync({required bool manual}) {
    if (_network.current == SyncConnectionKind.offline) return false;
    if (manual) return true;
    return switch (_networkPolicy) {
      SyncNetworkPolicy.manualOnly => false,
      SyncNetworkPolicy.anyNetwork => true,
      SyncNetworkPolicy.wifiOnly =>
        _network.current == SyncConnectionKind.wifi ||
            _network.current == SyncConnectionKind.other,
    };
  }

  Future<void> _pump({bool manual = false}) async {
    if (_syncing || !_networkAllowsSync(manual: manual)) {
      _refreshStatus();
      return;
    }
    final uid = _activeUid;
    if (uid == null || !_canSynchronize() || _currentUid() != uid) {
      _refreshStatus();
      return;
    }
    final jobs = _queue.where((item) => item.uid == uid);
    if (jobs.isEmpty) {
      await _pullRemote(uid);
      return;
    }
    _syncing = true;
    _errorMessage = null;
    _refreshStatus();
    final job = jobs.last;
    try {
      final result = await _gateway.push(
        uid,
        CloudSpaceSnapshot.fromLocal(job.data),
        expectedSyncToken: _cloudSyncToken,
      );
      if (result.conflict) {
        _status = CloudSyncStatus.conflict;
        notifyListeners();
        return;
      }
      _cloudSyncToken = result.syncToken;
      _queue.removeWhere(
        (item) => item.uid == uid && item.revision <= job.revision,
      );
      await _persist();
    } catch (error) {
      _errorMessage = '$error';
      await _persist();
    } finally {
      _syncing = false;
      _refreshStatus();
    }
    if (_queue.isNotEmpty && _errorMessage == null) {
      unawaited(_pump(manual: manual));
    }
  }

  Future<void> _pullRemote(String uid) async {
    _syncing = true;
    _errorMessage = null;
    _refreshStatus();
    try {
      final state = await _gateway.pull(uid);
      if (state.syncToken == null || state.syncToken == _cloudSyncToken) return;
      final bundle = LocalDataBundle(
        createdAt: DateTime.now(),
        data: state.snapshot.toLocalData(),
      ).encode();
      LocalDataBundle.decode(bundle);
      _applyingRemote = true;
      try {
        await _store.importBundle(bundle);
        _observedRevision = _store.persistenceRevision;
      } finally {
        _applyingRemote = false;
      }
      _cloudSyncToken = state.syncToken;
      await _persist();
    } catch (error) {
      _errorMessage = '$error';
      await _persist();
    } finally {
      _syncing = false;
      _refreshStatus();
    }
  }

  void _refreshStatus() {
    final next = _syncing
        ? CloudSyncStatus.synchronizing
        : _status == CloudSyncStatus.conflict
        ? CloudSyncStatus.conflict
        : _errorMessage != null
        ? CloudSyncStatus.failed
        : _queue.isEmpty
        ? CloudSyncStatus.synchronized
        : CloudSyncStatus.waitingForConnection;
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  void _schedulePersist() {
    _persistenceQueue = _persistenceQueue
        .catchError((_) {})
        .then((_) => _persist());
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _storageKey,
      jsonEncode({
        'schema': 'my_note.cloud_sync.v1',
        'activeUid': _activeUid,
        'cloudSyncToken': _cloudSyncToken,
        'networkPolicy': _networkPolicy.name,
        'queue': _queue.map((item) => item.toJson()).toList(growable: false),
      }),
    );
  }

  Future<void> flushPersistence() => _persistenceQueue;

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _account.removeListener(_onAccountChanged);
    unawaited(_networkSubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    _network.dispose();
    super.dispose();
  }
}

class CloudSyncScope extends InheritedNotifier<CloudSyncController> {
  const CloudSyncScope({
    super.key,
    required CloudSyncController controller,
    required super.child,
  }) : super(notifier: controller);

  static CloudSyncController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CloudSyncScope>();
    assert(scope != null, 'CloudSyncScope is missing.');
    return scope!.notifier!;
  }

  static CloudSyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CloudSyncScope>()?.notifier;
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
