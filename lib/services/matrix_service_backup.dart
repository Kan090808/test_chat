import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

class MatrixService extends ChangeNotifier {
  MatrixService();

  Client? client;

  bool _isInitializing = true;
  bool _isBusy = false;
  bool _isLoggedIn = false;
  bool _isInitialized = false; // New flag for successful init
  String _homeserver = 'https://matrix.org';
  String? _errorMessage;
  Room? _selectedRoom;
  StreamSubscription<SyncUpdate>? _syncSubscription;

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  bool get isLoggedIn => _isLoggedIn;
  String get homeserver => _homeserver;
  String? get errorMessage => _errorMessage;
  Room? get selectedRoom => _selectedRoom;

  List<Room> get joinedRooms =>
      client == null ? [] : List<Room>.from(client!.rooms);

  Future<void> initialize() async {
    if (!_isInitializing) {
      return;
    }
    try {
      // Initialize client with proper configuration
      client = Client(
        'test_chat_flutter',
        httpClient: _createHttpClient(),
      );
      await client!.init();
      _isInitialized = true; // Set only on success
      _syncSubscription = client!.onSync.stream.listen((_) {
        notifyListeners();
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to initialise Matrix client: $error\n$stackTrace');
      }
      _errorMessage = error.toString();
      _isInitialized = false; // Ensure flag is false on failure
      client = null; // Clean up on failure
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Creates an HTTP client with proper timeout and connection settings
  dynamic _createHttpClient() {
    try {
      // Try to create an HttpClient for better configuration
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 30);
      httpClient.idleTimeout = const Duration(seconds: 60);
      // Enable proper SSL/TLS handling
      httpClient.badCertificateCallback = (cert, host, port) {
        // In production, you should properly validate certificates
        if (kDebugMode) {
          debugPrint('Bad certificate for $host:$port');
        }
        return false; // Reject bad certificates in production
      };
      return httpClient;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to create custom HttpClient: $e');
      }
      return null; // Let Matrix SDK use default client
    }
  }

  Future<void> login({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    _setBusy(true);
    _errorMessage = null;

    // Ensure client is initialized before attempting login
    if (_isInitializing) {
      await initialize();
    }
    if (client == null) {
      _errorMessage = 'Client initialization failed. Please restart the app.';
      _setBusy(false);
      notifyListeners();
      return;
    }

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final trimmedHomeserver =
            homeserver.trim().isEmpty ? _homeserver : homeserver.trim();
        _homeserver = trimmedHomeserver;

        // Validate homeserver URL format
        final uri = Uri.tryParse(_homeserver);
        if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
          throw Exception('Invalid homeserver URL: $_homeserver');
        }

        // Check homeserver with timeout
        await client!
            .checkHomeserver(Uri.parse(_homeserver))
            .timeout(const Duration(seconds: 30));

        await client!
            .login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: username.trim()),
              password: password,
              initialDeviceDisplayName: 'Flutter Matrix Chat',
            )
            .timeout(const Duration(seconds: 45));

        _isLoggedIn = true;
        if (client!.rooms.isNotEmpty) {
          await selectRoom(client!.rooms.first);
        }
        break; // Success, exit retry loop
      } on TimeoutException {
        retryCount++;
        _errorMessage =
            'Connection timeout. ${retryCount < maxRetries ? 'Retrying...' : 'Please check your internet connection and try again.'}';
        if (retryCount < maxRetries) {
          if (kDebugMode) {
            debugPrint('Login attempt $retryCount timed out, retrying...');
          }
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }
      } on SocketException catch (e) {
        retryCount++;
        if (kDebugMode) {
          debugPrint('Socket error on attempt $retryCount: $e');
        }

        if (e.osError?.errorCode == 61 ||
            e.message.contains('Connection refused')) {
          _errorMessage =
              'Cannot connect to Matrix server. Please check the homeserver URL and your internet connection.';
        } else if (e.osError?.errorCode == 8 ||
            e.message.contains('nodename nor servname provided')) {
          _errorMessage =
              'Invalid homeserver address. Please check the URL format.';
        } else {
          _errorMessage =
              'Network error: ${e.message}. ${retryCount < maxRetries ? 'Retrying...' : 'Please try again later.'}';
        }

        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }
      } catch (error, stackTrace) {
        if (error.toString().contains('M_FORBIDDEN') ||
            error.toString().contains('Invalid username or password')) {
          _errorMessage =
              'Invalid username or password. Please check your credentials.';
        } else if (error.toString().contains('M_UNKNOWN') ||
            error.toString().contains('M_NOT_FOUND')) {
          _errorMessage =
              'Homeserver not found or not responding. Please check the server URL.';
        } else if (error.toString().contains('certificate') ||
            error.toString().contains('SSL') ||
            error.toString().contains('TLS')) {
          _errorMessage =
              'SSL/Certificate error. The server may have certificate issues.';
        } else {
          _errorMessage = error.toString();
        }

        if (kDebugMode) {
          debugPrint('Matrix login failed: $error\n$stackTrace');
        }
        break; // Don't retry for authentication errors
      }
    }

    _setBusy(false);
    notifyListeners();
  }

  Future<void> selectRoom(Room room) async {
    try {
      // Ensure client is initialized
      if (_isInitializing) {
        await initialize();
      }
      if (client == null) {
        return;
      }

      _selectedRoom = room;
      notifyListeners();
      final timeline =
          await room.getTimeline().timeout(const Duration(seconds: 30));
      if (timeline.events.isEmpty) {
        await timeline.requestHistory().timeout(const Duration(seconds: 30));
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to select room: $error');
      }
      _errorMessage = 'Failed to load room messages: ${error.toString()}';
      notifyListeners();
    }
  }

  Future<void> refreshSelectedRoom() async {
    final room = _selectedRoom;
    if (room == null) {
      return;
    }
    try {
      final timeline =
          await room.getTimeline().timeout(const Duration(seconds: 30));
      await timeline.requestHistory().timeout(const Duration(seconds: 30));
      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to refresh room: $error');
      }
      _errorMessage = 'Failed to refresh room: ${error.toString()}';
      notifyListeners();
    }
  }

  Future<void> sendMessage(String message) async {
    final room = _selectedRoom;
    final trimmed = message.trim();
    if (room == null || trimmed.isEmpty) {
      return;
    }
    try {
      await room.sendTextEvent(trimmed).timeout(const Duration(seconds: 30));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to send message: $error');
      }
      _errorMessage = 'Failed to send message: ${error.toString()}';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (client != null && !_isInitializing && _isLoggedIn) {
        await client!.logout().timeout(const Duration(seconds: 30));
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Matrix logout failed: $error\n$stackTrace');
      }
      // Continue with cleanup even if logout fails
    } finally {
      _isLoggedIn = false;
      _selectedRoom = null;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    if (client != null && !_isInitializing && _isInitialized) {
      client!.dispose();
    }
    super.dispose();
  }
}
