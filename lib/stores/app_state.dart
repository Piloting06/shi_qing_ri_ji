import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/keys.dart';

class AppState extends ChangeNotifier {
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _displayName = '';
  int _windowWidth = 0;
  bool _animActive = true;
  bool _lockedOut = false;
  int _moodRevision = 0;

  AppState() {
    _loadAnimActive();
  }

  Future<void> _loadAnimActive() async {
    final prefs = await SharedPreferences.getInstance();
    _animActive = prefs.getBool(StorageKeys.animActive) ?? true;
    notifyListeners();
  }

  String get selectedDate => _selectedDate;
  String get displayName => _displayName;
  int get windowWidth => _windowWidth;
  bool get animActive => _animActive;
  bool get isLockedOut => _lockedOut;

  /// 心情记录变动计数：保存/删除后递增，首页据此刷新「今天」栏
  int get moodRevision => _moodRevision;

  void bumpMoodRevision() {
    _moodRevision++;
    notifyListeners();
  }

  void setSelectedDate(String d) {
    if (_selectedDate != d) {
      _selectedDate = d;
      notifyListeners();
    }
  }

  void setDisplayName(String n) {
    if (_displayName != n) {
      _displayName = n;
      notifyListeners();
    }
  }

  void clearUser() {
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _displayName = '';
    _animActive = false;
    notifyListeners();
  }

  void setLockedOut(bool v) {
    if (_lockedOut != v) {
      _lockedOut = v;
      notifyListeners();
    }
  }

  void setWindowWidth(int w) {
    _windowWidth = w;
  }

  Future<void> setAnimActive(bool a) async {
    if (_animActive != a) {
      _animActive = a;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.animActive, a);
    }
  }
}
