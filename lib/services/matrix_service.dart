import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

class MatrixService extends ChangeNotifier {
  MatrixService();

  final Client client = Client('test_chat_flutter');

  bool _isInitializing = true;
  bool _isBusy = false;
  bool _isLoggedIn = false;
  String _homeserver = 'https://matrix-client.matrix.org';
  String? _errorMessage;
  Room? _selectedRoom;
  StreamSubscription<SyncUpdate>? _syncSubscription;

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  bool get isLoggedIn => _isLoggedIn;
  String get homeserver => _homeserver;
  String? get errorMessage => _errorMessage;
  Room? get selectedRoom => _selectedRoom;

  List<Room> get joinedRooms => List<Room>.from(client.rooms);

  Future<void> initialize() async {
    if (!_isInitializing) {
      return;
    }
    try {
      await client.init();
      _syncSubscription = client.onSync.stream.listen((_) {
        notifyListeners();
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to initialise Matrix client: $error\n$stackTrace');
      }
      _errorMessage = error.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final trimmedHomeserver = homeserver.trim().isEmpty
          ? _homeserver
          : homeserver.trim();
      _homeserver = trimmedHomeserver;

      await client.setUrl(Uri.parse(_homeserver));
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username.trim()),
        password: password,
        initialDeviceDisplayName: 'Flutter Matrix Chat',
      );
      await client.startSync();
      _isLoggedIn = true;
      if (client.rooms.isNotEmpty) {
        await selectRoom(client.rooms.first);
      }
    } catch (error, stackTrace) {
      _errorMessage = error.toString();
      if (kDebugMode) {
        debugPrint('Matrix login failed: $error\n$stackTrace');
      }
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> selectRoom(Room room) async {
    _selectedRoom = room;
    notifyListeners();
    final timeline = room.timeline;
    if (timeline != null && timeline.events.isEmpty) {
      await timeline.requestHistory();
      notifyListeners();
    }
  }

  Future<void> refreshSelectedRoom() async {
    final room = _selectedRoom;
    if (room == null) {
      return;
    }
    final timeline = room.timeline;
    if (timeline != null) {
      await timeline.requestHistory();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String message) async {
    final room = _selectedRoom;
    final trimmed = message.trim();
    if (room == null || trimmed.isEmpty) {
      return;
    }
    await room.sendTextEvent(trimmed);
  }

  Future<void> logout() async {
    try {
      await client.logout();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Matrix logout failed: $error\n$stackTrace');
      }
    }
    _isLoggedIn = false;
    _selectedRoom = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_syncSubscription?.cancel());
    unawaited(client.dispose());
    super.dispose();
  }
}
