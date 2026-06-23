# M2 — Flutter 骨架 + 拍照识别闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter app that lets users take/select a photo, upload it to the backend, and view the recognized parts list.

**Architecture:** Single Flutter app with Provider + ChangeNotifier for state management, sqflite for local storage, and a dedicated ApiClient for backend communication. 5 pages connected via GoRouter.

**Tech Stack:** Flutter 3.x, Dart 3.x, sqflite, path_provider, http, image_picker, image_compression, go_router, provider, flutter_l10n, flutter_test.

**Prerequisites:** Flutter SDK must be installed on the development machine.

## Global Constraints

- LEGO-style color palette: Red #ED1C24, Yellow #FFD700, Blue #0055BF, Dark text #333, Light gray bg #f8f8f8
- Chinese-first UI with English fallback via ARB files
- All HTTP I/O via `http` package
- Image upload max 8 MB, compress to 1600px long edge JPEG q=85 before upload
- No user business data stored on backend; local SQLite only
- Every API error normalized into one of 5 client-side codes
- Provider + ChangeNotifier for state management (no third-party state libs)
- Test with `flutter_test` (unit + widget)

---

### Task 1: Flutter project scaffold

**Files:**
- Create: `app/pubspec.yaml`
- Create: `app/lib/main.dart`
- Create: `app/lib/app_router.dart`
- Create: `app/lib/theme/app_theme.dart`
- Create: `app/lib/l10n/app_zh.arb`
- Create: `app/lib/l10n/app_en.arb`
- Create: `app/lib/l10n/app_localizations.dart`
- Create: `app/analysis_options.yaml`
- Create: `app/test/widget/placeholder_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Flutter project with routing, theming, and i18n wired together. `flutter analyze` and `flutter test` pass.

- [ ] **Step 1: Create pubspec.yaml**

Create `app/pubspec.yaml`:

```yaml
name: brickfinder
description: "Lego photo build finder"
publish_to: 'none'
version: 0.2.0

environment:
  sdk: ^3.2.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^14.0.0
  provider: ^6.1.0
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  http: ^1.2.0
  image_picker: ^1.0.0
  image: ^4.0.0
  intl: ^0.19.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/images/
```

- [ ] **Step 2: Create analysis_options.yaml**

Create `app/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: false
```

- [ ] **Step 3: Create theme**

Create `app/lib/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color legoRed = Color(0xFFED1C24);
  static const Color legoYellow = Color(0xFFFFD700);
  static const Color legoBlue = Color(0xFF0055BF);
  static const Color darkText = Color(0xFF333333);
  static const Color lightBg = Color(0xFFF8F8F8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: legoRed,
        primary: legoRed,
        secondary: legoYellow,
        tertiary: legoBlue,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: legoRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
```

- [ ] **Step 4: Create i18n ARB files**

Create `app/lib/l10n/app_zh.arb`:

```json
{
  "@@locale": "zh",
  "appTitle": "BrickFinder",
  "homeTitle": "首页",
  "captureTitle": "拍照识别",
  "photoGuide": "把砖块平铺在浅色背景上，不要堆叠，效果更好",
  "takePhoto": "拍照",
  "pickFromGallery": "从相册选择",
  "confirmTitle": "确认照片",
  "photoSelected": "已选 1 张照片",
  "retake": "重新拍",
  "startRecognize": "开始识别",
  "recognizing": "正在识别砖块…",
  "estimateTime": "大约需要 5-15 秒",
  "cancel": "取消",
  "partList": "零件清单",
  "partCount": "共识别 {count} 种零件 · {total} 件",
  "unknownColor": "未知颜色",
  "confidence": "置信度",
  "emptyHome": "点击上方按钮，拍照识别你的乐高砖块",
  "emptyResult": "未识别出零件，试试换个角度或光线",
  "retakePhoto": "重新拍/选",
  "favorites": "收藏",
  "settings": "设置",
  "history": "历史清单",
  "recognitionTime": "耗时",
  "seconds": "秒",
  "addPart": "手动加",
  "retakeHint": "建议把砖块平铺在浅色背景上识别效果更好"
}
```

Create `app/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "BrickFinder",
  "homeTitle": "Home",
  "captureTitle": "Scan",
  "photoGuide": "Place bricks on a light background for best results",
  "takePhoto": "Take Photo",
  "pickFromGallery": "Choose from Gallery",
  "confirmTitle": "Confirm Photo",
  "photoSelected": "1 photo selected",
  "retake": "Retake",
  "startRecognize": "Start Recognition",
  "recognizing": "Recognizing bricks…",
  "estimateTime": "About 5-15 seconds",
  "cancel": "Cancel",
  "partList": "Parts List",
  "partCount": "{count} types · {total} pcs",
  "unknownColor": "Unknown color",
  "confidence": "Confidence",
  "emptyHome": "Tap the button above to scan your Lego bricks",
  "emptyResult": "No parts recognized. Try a different angle or lighting",
  "retakePhoto": "Retake",
  "favorites": "Favorites",
  "settings": "Settings",
  "history": "History",
  "recognitionTime": "Time",
  "seconds": "s",
  "addPart": "Add Part",
  "retakeHint": "Place bricks on a light background for better recognition"
}
```

Create `app/lib/l10n/app_localizations.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

export 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppLocalization {
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }
}
```

- [ ] **Step 5: Create app_router.dart**

Create `app/lib/app_router.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Pages will be imported later
import 'pages/home/home_page.dart';
import 'pages/capture/capture_page.dart';
import 'pages/confirm/confirm_page.dart';
import 'pages/loading/loading_page.dart';
import 'pages/result/result_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/capture', builder: (context, state) => const CapturePage()),
    GoRoute(path: '/confirm', builder: (context, state) {
      final imagePath = state.extra as String;
      return ConfirmPage(imagePath: imagePath);
    }),
    GoRoute(path: '/loading', builder: (context, state) {
      final imagePath = state.extra as String;
      return LoadingPage(imagePath: imagePath);
    }),
    GoRoute(
      path: '/result/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return ResultPage(sessionId: sessionId);
      },
    ),
  ],
);
```

- [ ] **Step 6: Create main.dart**

Create `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'theme/app_theme.dart';
import 'repository/local_repository.dart';
import 'api/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => LocalRepository()),
        Provider(create: (_) => ApiClient()),
      ],
      child: const BrickFinderApp(),
    ),
  );
}

class BrickFinderApp extends StatelessWidget {
  const BrickFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BrickFinder',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
    );
  }
}
```

- [ ] **Step 7: Add l10n config to pubspec.yaml**

Append to `app/pubspec.yaml`:

```yaml
flutter_intl:
  enabled: true
  class_name: AppLocalizations
  main_locale: zh
  arb_dir: lib/l10n
  output_dir: lib/l10n/generated
```

- [ ] **Step 8: Create placeholder test**

Create `app/test/widget/placeholder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder', (tester) async {
    expect(1 + 1, equals(2));
  });
}
```

- [ ] **Step 9: Verify scaffold**

```bash
cd app
flutter pub get
flutter analyze
flutter test
```

Expected: `flutter analyze` no errors. `flutter test` 1 test passed.

- [ ] **Step 10: Commit**

```bash
git add app/
git commit -m "feat(app): Flutter project scaffold with routing, theme, i18n"
```

---

### Task 2: Data models and local repository

**Files:**
- Create: `app/lib/models/inventory_session.dart`
- Create: `app/lib/models/inventory_part.dart`
- Create: `app/lib/models/recognize_response.dart`
- Create: `app/lib/repository/database_helper.dart`
- Create: `app/lib/repository/local_repository.dart`
- Create: `app/test/unit/models_test.dart`
- Create: `app/test/unit/repository_test.dart`

**Interfaces:**
- Consumes: nothing (standalone data layer)
- Produces:
  - `class InventorySession` with `id`, `name`, `createdAt`, `updatedAt`, `partCount`, `thumbnail`
  - `class InventoryPart` with `partNum`, `colorId`, `quantity`, `source`, `confidence`, `colorName`
  - `class RecognizeResponse` with `parts`, `cacheHit`, `lowConfidenceCount`
  - `class LocalRepository` with CRUD methods for sessions and parts

- [ ] **Step 1: Write models test**

Create `app/test/unit/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/models/inventory_session.dart';
import 'package:brickfinder/models/inventory_part.dart';
import 'package:brickfinder/models/recognize_response.dart';

void main() {
  group('InventorySession', () {
    test('fromMap and toMap round-trip', () {
      final now = DateTime.now();
      final session = InventorySession(
        id: 'test-id',
        name: 'Test Session',
        createdAt: now,
        updatedAt: now,
        partCount: 5,
        thumbnail: null,
      );
      final map = session.toMap();
      final restored = InventorySession.fromMap(map);
      expect(restored.id, equals('test-id'));
      expect(restored.name, equals('Test Session'));
      expect(restored.partCount, equals(5));
    });
  });

  group('InventoryPart', () {
    test('fromMap and toMap round-trip', () {
      final part = InventoryPart(
        sessionId: 's1',
        partNum: '3001',
        colorId: 4,
        quantity: 2,
        source: 'recognized',
        confidence: 0.9,
        colorName: 'Red',
      );
      final map = part.toMap();
      final restored = InventoryPart.fromMap(map);
      expect(restored.partNum, equals('3001'));
      expect(restored.colorId, equals(4));
      expect(restored.quantity, equals(2));
    });

    test('equality based on (partNum, colorId)', () {
      final a = InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2, source: 'recognized');
      final b = InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 5, source: 'recognized');
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('RecognizeResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'parts': [{'part_num': '3001', 'color_id': 4, 'quantity': 2, 'confidence': 0.9}],
        'cache_hit': false,
        'low_confidence_count': 0,
      };
      final resp = RecognizeResponse.fromJson(json);
      expect(resp.parts.length, equals(1));
      expect(resp.parts[0].partNum, equals('3001'));
      expect(resp.cacheHit, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run, expect failure**

```bash
cd app
flutter test test/unit/models_test.dart
```

Expected: ImportError — models don't exist yet.

- [ ] **Step 3: Create data models**

Create `app/lib/models/inventory_session.dart`:

```dart
class InventorySession {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int partCount;
  final String? thumbnail;

  const InventorySession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.partCount = 0,
    this.thumbnail,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'part_count': partCount,
    'thumbnail': thumbnail,
  };

  factory InventorySession.fromMap(Map<String, dynamic> map) => InventorySession(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    partCount: map['part_count'] as int? ?? 0,
    thumbnail: map['thumbnail'] as String?,
  );
}
```

Create `app/lib/models/inventory_part.dart`:

```dart
class InventoryPart {
  final String sessionId;
  final String partNum;
  final int colorId;
  final int quantity;
  final String source; // 'recognized' | 'manual' | 'edited'
  final double? confidence;
  final String? colorName;

  const InventoryPart({
    required this.sessionId,
    required this.partNum,
    required this.colorId,
    this.quantity = 1,
    this.source = 'recognized',
    this.confidence,
    this.colorName,
  });

  InventoryPart copyWith({int? quantity, String? source}) => InventoryPart(
    sessionId: sessionId,
    partNum: partNum,
    colorId: colorId,
    quantity: quantity ?? this.quantity,
    source: source ?? this.source,
    confidence: confidence,
    colorName: colorName,
  );

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'part_num': partNum,
    'color_id': colorId,
    'quantity': quantity,
    'source': source,
    'confidence': confidence,
    'color_name': colorName,
  };

  factory InventoryPart.fromMap(Map<String, dynamic> map) => InventoryPart(
    sessionId: map['session_id'] as String,
    partNum: map['part_num'] as String,
    colorId: map['color_id'] as int,
    quantity: map['quantity'] as int? ?? 1,
    source: map['source'] as String? ?? 'recognized',
    confidence: (map['confidence'] as num?)?.toDouble(),
    colorName: map['color_name'] as String?,
  );

  @override
  bool operator ==(Object other) =>
    other is InventoryPart && other.partNum == partNum && other.colorId == colorId;

  @override
  int get hashCode => Object.hash(partNum, colorId);
}
```

Create `app/lib/models/recognize_response.dart`:

```dart
class PartItem {
  final String partNum;
  final int colorId;
  final int quantity;
  final double? confidence;

  const PartItem({
    required this.partNum,
    required this.colorId,
    this.quantity = 1,
    this.confidence,
  });

  factory PartItem.fromJson(Map<String, dynamic> json) => PartItem(
    partNum: json['part_num'] as String,
    colorId: json['color_id'] as int,
    quantity: json['quantity'] as int? ?? 1,
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}

class RecognizeResponse {
  final List<PartItem> parts;
  final bool cacheHit;
  final int lowConfidenceCount;

  const RecognizeResponse({
    required this.parts,
    required this.cacheHit,
    required this.lowConfidenceCount,
  });

  factory RecognizeResponse.fromJson(Map<String, dynamic> json) => RecognizeResponse(
    parts: (json['parts'] as List).map((e) => PartItem.fromJson(e as Map<String, dynamic>)).toList(),
    cacheHit: json['cache_hit'] as bool? ?? false,
    lowConfidenceCount: json['low_confidence_count'] as int? ?? 0,
  );
}
```

- [ ] **Step 4: Run models test**

```bash
cd app
flutter test test/unit/models_test.dart
```

Expected: 3 passed.

- [ ] **Step 5: Write repository test**

Create `app/test/unit/repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/models/inventory_session.dart';
import 'package:brickfinder/models/inventory_part.dart';

void main() {
  late LocalRepository repo;

  setUp(() async {
    repo = LocalRepository(inMemory: true);
    await repo.init();
  });

  tearDown(() async {
    await repo.close();
  });

  group('sessions', () {
    test('insert and retrieve session', () async {
      final session = InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      await repo.insertSession(session);
      final sessions = await repo.getAllSessions();
      expect(sessions.length, equals(1));
      expect(sessions.first.id, equals('s1'));
    });

    test('getSession returns null for missing', () async {
      final session = await repo.getSession('nonexistent');
      expect(session, isNull);
    });
  });

  group('parts', () {
    test('insert and retrieve parts', () async {
      await repo.insertSession(InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3003', colorId: 4, quantity: 1));
      final parts = await repo.getParts('s1');
      expect(parts.length, equals(2));
    });

    test('same part_num+colorId merges quantity', () async {
      await repo.insertSession(InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 3));
      final parts = await repo.getParts('s1');
      expect(parts.length, equals(1));
      expect(parts.first.quantity, equals(5));
    });
  });
}
```

- [ ] **Step 6: Create database helper**

Create `app/lib/repository/database_helper.dart`:

```dart
import 'package:sqflite/sqflite.dart';

const String _createSessionTable = '''
CREATE TABLE IF NOT EXISTS inventory_session (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  part_count INTEGER NOT NULL DEFAULT 0,
  thumbnail TEXT
)
''';

const String _createPartTable = '''
CREATE TABLE IF NOT EXISTS inventory_part (
  session_id TEXT NOT NULL REFERENCES inventory_session(id) ON DELETE CASCADE,
  part_num TEXT NOT NULL,
  color_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL DEFAULT 'recognized',
  confidence REAL,
  color_name TEXT,
  PRIMARY KEY (session_id, part_num, color_id)
)
''';

Future<Database> openDatabase({required String path, required bool inMemory}) async {
  final db = inMemory
      ? await databaseFactoryInMemory.openDatabase(path)
      : await openDatabase(path, version: 1, onCreate: (db, version) async {
          await db.execute(_createSessionTable);
          await db.execute(_createPartTable);
        });
  if (inMemory) {
    await db.execute(_createSessionTable);
    await db.execute(_createPartTable);
  }
  return db;
}
```

- [ ] **Step 7: Create LocalRepository**

Create `app/lib/repository/local_repository.dart`:

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/inventory_session.dart';
import '../models/inventory_part.dart';
import 'database_helper.dart';

class LocalRepository {
  Database? _db;
  final bool inMemory;

  LocalRepository({this.inMemory = false});

  Future<void> init() async {
    if (inMemory) {
      _db = await openDatabase(path: '', inMemory: true);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'brickfinder.db');
      _db = await openDatabase(path: path, inMemory: false);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Database get _database {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  // Sessions
  Future<List<InventorySession>> getAllSessions() async {
    final maps = await _database.query('inventory_session', orderBy: 'created_at DESC');
    return maps.map(InventorySession.fromMap).toList();
  }

  Future<InventorySession?> getSession(String id) async {
    final maps = await _database.query('inventory_session', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return InventorySession.fromMap(maps.first);
  }

  Future<void> insertSession(InventorySession session) async {
    await _database.insert('inventory_session', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSession(String id) async {
    await _database.delete('inventory_session', where: 'id = ?', whereArgs: [id]);
  }

  // Parts
  Future<List<InventoryPart>> getParts(String sessionId) async {
    final maps = await _database.query('inventory_part', where: 'session_id = ?', whereArgs: [sessionId]);
    return maps.map(InventoryPart.fromMap).toList();
  }

  Future<void> insertPart(InventoryPart part) async {
    await _database.insert('inventory_part', part.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
```

- [ ] **Step 8: Run repository test**

```bash
cd app
flutter test test/unit/repository_test.dart
```

Expected: 4 passed.

- [ ] **Step 9: Commit**

```bash
git add app/lib/models/ app/lib/repository/ app/test/unit/
git commit -m "feat(app): data models and local SQLite repository"
```

---

### Task 3: API Client and image compression

**Files:**
- Create: `app/lib/api/api_client.dart`
- Create: `app/lib/api/api_exceptions.dart`
- Create: `app/lib/utils/image_compressor.dart`
- Create: `app/test/unit/api_client_test.dart`

**Interfaces:**
- Consumes: `LocalRepository` (for saving results)
- Produces:
  - `class ApiClient` with `Future<RecognizeResponse> recognize({required String imagePath})`
  - `class ApiException` with `code` field
  - `enum ApiError` with values `invalidInput`, `upstreamTimeout`, `upstreamError`, `rateLimited`, `internal`, `networkError`
  - `Future<String> compressImage(String sourcePath, {int maxDimension = 1600, int quality = 85})`

- [ ] **Step 1: Write failing test**

Create `app/test/unit/api_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/api/api_client.dart';
import 'package:brickfinder/api/api_exceptions.dart';

void main() {
  group('ApiClient', () {
    test('recognize with non-existent file throws', () async {
      final client = ApiClient(baseUrl: 'http://test');
      expect(
        () => client.recognize(imagePath: '/nonexistent.jpg'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run, expect failure**

```bash
cd app
flutter test test/unit/api_client_test.dart
```

Expected: ImportError.

- [ ] **Step 3: Create ApiException**

Create `app/lib/api/api_exceptions.dart`:

```dart
enum ApiError {
  invalidInput,
  upstreamTimeout,
  upstreamError,
  rateLimited,
  internal,
  networkError,
}

class ApiException implements Exception {
  final ApiError code;
  final String message;
  final int? retryAfterSeconds;

  const ApiException({required this.code, this.message = '', this.retryAfterSeconds});

  @override
  String toString() => 'ApiException($code): $message';
}
```

- [ ] **Step 4: Create ApiClient**

Create `app/lib/api/api_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/recognize_response.dart';
import 'api_exceptions.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({this.baseUrl = 'http://localhost:8000', http.Client? client})
      : _client = client ?? http.Client();

  Future<RecognizeResponse> recognize({required String imagePath}) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw const ApiException(code: ApiError.invalidInput, message: 'File not found');
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/recognize'));
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RecognizeResponse.fromJson(json);
      }

      final code = _mapError(response.statusCode);
      throw ApiException(code: code, message: response.body);
    } on SocketException {
      throw const ApiException(code: ApiError.networkError, message: 'No network connection');
    } on http.ClientException {
      throw const ApiException(code: ApiError.networkError, message: 'Connection failed');
    }
  }

  static ApiError _mapError(int statusCode) {
    switch (statusCode) {
      case 400: return ApiError.invalidInput;
      case 429: return ApiError.rateLimited;
      case 502: return ApiError.upstreamError;
      case 504: return ApiError.upstreamTimeout;
      default: return ApiError.internal;
    }
  }

  void dispose() {
    _client.close();
  }
}
```

- [ ] **Step 5: Create image compressor**

Create `app/lib/utils/image_compressor.dart`:

```dart
import 'dart:io';
import 'package:image/image.dart' as img;

Future<String> compressImage(String sourcePath, {int maxDimension = 1600, int quality = 85}) async {
  final original = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (original == null) return sourcePath;

  final image = original.width > original.height
      ? img.copyResize(original, width: maxDimension)
      : img.copyResize(original, height: maxDimension);

  final compressed = img.encodeJpg(image, quality: quality);
  final outPath = '${sourcePath}_compressed.jpg';
  await File(outPath).writeAsBytes(compressed);
  return outPath;
}
```

- [ ] **Step 6: Run test**

```bash
cd app
flutter test test/unit/api_client_test.dart
```

Expected: 1 passed.

- [ ] **Step 7: Commit**

```bash
git add app/lib/api/ app/lib/utils/ app/test/unit/api_client_test.dart
git commit -m "feat(app): API client and image compression"
```

---

### Task 4: Home page (session list)

**Files:**
- Create: `app/lib/pages/home/home_page.dart`
- Create: `app/lib/pages/home/home_page_vm.dart`
- Create: `app/lib/widgets/empty_state.dart`
- Create: `app/test/widget/home_page_test.dart`
- Create: `app/assets/images/capture_guide.png` (placeholder)

**Interfaces:**
- Consumes: `LocalRepository` (from Provider)
- Produces: HomePage widget with session list and photo capture button

- [ ] **Step 1: Write widget test**

Create `app/test/widget/home_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

Widget createTestWidget() {
  return MaterialApp(
    home: ChangeNotifierProvider(
      create: (_) => HomePageViewModel(repository: LocalRepository(inMemory: true)),
      child: const HomePage(),
    ),
  );
}

void main() {
  testWidgets('home page shows empty state', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Create HomePageViewModel**

Create `app/lib/pages/home/home_page_vm.dart`:

```dart
import 'package:flutter/foundation.dart';
import '../../models/inventory_session.dart';
import '../../repository/local_repository.dart';

class HomePageViewModel extends ChangeNotifier {
  final LocalRepository _repository;
  List<InventorySession> _sessions = [];
  bool _loading = true;

  HomePageViewModel({required LocalRepository repository}) : _repository = repository;

  List<InventorySession> get sessions => _sessions;
  bool get loading => _loading;

  Future<void> loadSessions() async {
    _loading = true;
    notifyListeners();
    _sessions = await _repository.getAllSessions();
    _loading = false;
    notifyListeners();
  }
}
```

- [ ] **Step 3: Create empty_state widget**

Create `app/lib/widgets/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create HomePage**

Create `app/lib/pages/home/home_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_session.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<InventorySession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final repo = context.read<LocalRepository>();
    final sessions = await repo.getAllSessions();
    setState(() { _sessions = sessions; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrickFinder'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Photo button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/capture'),
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text('拍照识别', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.legoYellow,
                  foregroundColor: AppTheme.darkText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('历史清单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                Text('共 ${_sessions.length} 次识别', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),

          // Session list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? const EmptyState(icon: Icons.inventory_2_outlined, message: '点击上方按钮，拍照识别你的乐高砖块')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) => _SessionCard(_sessions[index]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final InventorySession session;
  const _SessionCard(this.session);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.grid_view_rounded, color: Colors.grey),
        ),
        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${session.partCount} 种零件', style: TextStyle(color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.legoBlue),
        onTap: () => context.push('/result/${session.id}'),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: AppTheme.legoRed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
        BottomNavigationBarItem(icon: Icon(Icons.star_border), label: '收藏'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ],
    );
  }
}
```

- [ ] **Step 5: Create placeholder asset**

```bash
mkdir -p app/assets/images
# Create a minimal placeholder PNG (1x1 transparent pixel)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\x15\xa0\xbb\xad\x00\x00\x00\x00IEND\xaeB`\x82' > app/assets/images/capture_guide.png
```

- [ ] **Step 6: Run widget test**

```bash
cd app
flutter test test/widget/home_page_test.dart
```

Expected: 1 passed.

- [ ] **Step 7: Commit**

```bash
git add app/lib/pages/home/ app/lib/widgets/ app/test/widget/home_page_test.dart app/assets/
git commit -m "feat(app): home page with session list and capture button"
```

---

### Task 5: Capture page (photo selection)

**Files:**
- Create: `app/lib/pages/capture/capture_page.dart`
- Create: `app/test/widget/capture_page_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: CapturePage widget that launches camera/gallery and navigates to confirm page

- [ ] **Step 1: Create CapturePage**

Create `app/lib/pages/capture/capture_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null && context.mounted) {
      context.push('/confirm', extra: image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Guide image placeholder
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('拍摄示意图', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('把砖块平铺在浅色背景上，不要堆叠，效果更好',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.legoRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('从相册选择', style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.legoBlue,
                  side: const BorderSide(color: AppTheme.legoBlue, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create widget test**

Create `app/test/widget/capture_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/capture/capture_page.dart';

void main() {
  testWidgets('capture page shows both buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CapturePage()));
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test**

```bash
cd app
flutter test test/widget/capture_page_test.dart
```

Expected: 1 passed.

- [ ] **Step 4: Commit**

```bash
git add app/lib/pages/capture/ app/test/widget/capture_page_test.dart
git commit -m "feat(app): capture page with camera and gallery options"
```

---

### Task 6: Confirm page

**Files:**
- Create: `app/lib/pages/confirm/confirm_page.dart`
- Create: `app/test/widget/confirm_page_test.dart`

**Interfaces:**
- Consumes: `imagePath` (route extra)
- Produces: ConfirmPage widget that shows photo preview and navigates to loading page

- [ ] **Step 1: Create ConfirmPage**

Create `app/lib/pages/confirm/confirm_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class ConfirmPage extends StatelessWidget {
  final String imagePath;
  const ConfirmPage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认照片')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('已选 1 张照片', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text('建议把砖块平铺在浅色背景上识别效果更好',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('重新拍/选'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => context.push('/loading', extra: imagePath),
                    child: const Text('开始识别', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.legoYellow,
                      foregroundColor: AppTheme.darkText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create widget test**

Create `app/test/widget/confirm_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/confirm/confirm_page.dart';

void main() {
  testWidgets('confirm page shows buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ConfirmPage(imagePath: '/test'),
    ));
    expect(find.text('重新拍/选'), findsOneWidget);
    expect(find.text('开始识别'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test**

```bash
cd app
flutter test test/widget/confirm_page_test.dart
```

Expected: 1 passed.

- [ ] **Step 4: Commit**

```bash
git add app/lib/pages/confirm/ app/test/widget/confirm_page_test.dart
git commit -m "feat(app): confirm page with photo preview"
```

---

### Task 7: Loading page (recognition in progress)

**Files:**
- Create: `app/lib/pages/loading/loading_page.dart`
- Create: `app/lib/pages/loading/loading_page_vm.dart`
- Create: `app/test/widget/loading_page_test.dart`

**Interfaces:**
- Consumes: `imagePath` (route extra), `ApiClient` + `LocalRepository` (from Provider)
- Produces: LoadingPage that uploads image, calls recognize, saves result, navigates to result page

- [ ] **Step 1: Create LoadingPageViewModel**

Create `app/lib/pages/loading/loading_page_vm.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../models/inventory_session.dart';
import '../../models/inventory_part.dart';
import '../../models/recognize_response.dart';
import '../../repository/local_repository.dart';
import '../../utils/image_compressor.dart';

enum LoadingState { compressing, uploading, recognizing, done, error }

class LoadingPageViewModel extends ChangeNotifier {
  final ApiClient _api;
  final LocalRepository _repo;
  LoadingState _state = LoadingState.compressing;
  String? _errorMessage;
  String? _resultSessionId;

  LoadingPageViewModel({required ApiClient api, required LocalRepository repo})
      : _api = api, _repo = repo;

  LoadingState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get resultSessionId => _resultSessionId;

  Future<void> start(String imagePath) async {
    try {
      _state = LoadingState.compressing;
      notifyListeners();

      final compressed = await compressImage(imagePath);

      _state = LoadingState.uploading;
      notifyListeners();

      final response = await _api.recognize(imagePath: compressed);

      _state = LoadingState.recognizing;
      notifyListeners();

      // Save to local database
      final sessionId = const Uuid().v4();
      final now = DateTime.now();
      final session = InventorySession(
        id: sessionId,
        name: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 识别',
        createdAt: now,
        updatedAt: now,
        partCount: response.parts.length,
      );
      await _repo.insertSession(session);

      for (final item in response.parts) {
        await _repo.insertPart(InventoryPart(
          sessionId: sessionId,
          partNum: item.partNum,
          colorId: item.colorId,
          quantity: item.quantity,
          confidence: item.confidence,
          source: 'recognized',
        ));
      }

      _resultSessionId = sessionId;
      _state = LoadingState.done;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message.isNotEmpty ? e.message : _errorLabel(e.code);
      _state = LoadingState.error;
      notifyListeners();
    } catch (e) {
      _errorMessage = '识别失败，请重试';
      _state = LoadingState.error;
      notifyListeners();
    }
  }

  String _errorLabel(ApiError code) {
    switch (code) {
      case ApiError.invalidInput: return '图片有问题，请重选';
      case ApiError.upstreamTimeout: return '网络慢，再试一次';
      case ApiError.upstreamError: return '识别服务暂时不可用';
      case ApiError.rateLimited: return '今天用得有点多，过会儿再来';
      case ApiError.networkError: return '网络连接失败，请检查网络';
      case ApiError.internal: return '出错了，已记录';
    }
  }
}
```

- [ ] **Step 2: Create LoadingPage**

Create `app/lib/pages/loading/loading_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../repository/local_repository.dart';
import 'loading_page_vm.dart';

class LoadingPage extends StatefulWidget {
  final String imagePath;
  const LoadingPage({super.key, required this.imagePath});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  late LoadingPageViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LoadingPageViewModel(
      api: context.read<ApiClient>(),
      repo: context.read<LocalRepository>(),
    );
    _vm.addListener(_onStateChanged);
    _vm.start(widget.imagePath);
  }

  @override
  void dispose() {
    _vm.removeListener(_onStateChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (_vm.state == LoadingState.done && _vm.resultSessionId != null && mounted) {
      context.go('/result/${_vm.resultSessionId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('识别中')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_vm.state == LoadingState.error)
                Column(
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_vm.errorMessage ?? '识别失败', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => context.pop(), child: const Text('返回重试')),
                  ],
                )
              else
                Column(
                  children: [
                    const SizedBox(height: 16),
                    _AnimatedBrick(),
                    const SizedBox(height: 24),
                    const Text('正在识别砖块…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('大约需要 5-15 秒', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    TextButton(onPressed: () => context.pop(), child: const Text('取消')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBrick extends StatefulWidget {
  @override
  State<_AnimatedBrick> createState() => _AnimatedBrickState();
}

class _AnimatedBrickState extends State<_AnimatedBrick> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Text('🧱', style: TextStyle(fontSize: 64)),
    );
  }
}
```

- [ ] **Step 3: Create widget test**

Create `app/test/widget/loading_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/loading/loading_page.dart';
import 'package:brickfinder/api/api_client.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('loading page shows recognizing text', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
          Provider(create: (_) => LocalRepository(inMemory: true)),
        ],
        child: const MaterialApp(home: LoadingPage(imagePath: '/test')),
      ),
    );
    expect(find.text('正在识别砖块…'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test**

```bash
cd app
flutter test test/widget/loading_page_test.dart
```

Expected: 1 passed.

- [ ] **Step 5: Commit**

```bash
git add app/lib/pages/loading/ app/test/widget/loading_page_test.dart
git commit -m "feat(app): loading page with upload and recognition flow"
```

---

### Task 8: Result page (parts list)

**Files:**
- Create: `app/lib/pages/result/result_page.dart`
- Create: `app/lib/widgets/part_card.dart`
- Create: `app/test/widget/result_page_test.dart`

**Interfaces:**
- Consumes: `sessionId` (route param), `LocalRepository` (from Provider)
- Produces: ResultPage widget showing the recognized parts list

- [ ] **Step 1: Create PartCard widget**

Create `app/lib/widgets/part_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/inventory_part.dart';

class PartCard extends StatelessWidget {
  final InventoryPart part;

  const PartCard({super.key, required this.part});

  Color _colorFromId(int id) {
    switch (id) {
      case 0: return Colors.black;
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 4: return const Color(0xFFED1C24);
      case 5: return const Color(0xFFE91E63);
      case 7: return Colors.grey;
      case 14: return const Color(0xFFFFD700);
      case 15: return Colors.white;
      case 71: return Colors.blueGrey;
      case 72: return Colors.blueGrey[800]!;
      default: return Colors.grey[300]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = part.confidence != null && part.confidence < 0.6;
    final isUnknownColor = part.colorId == -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isLowConfidence ? const Color(0xFFFFF8E1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isLowConfidence ? Border.all(color: const Color(0xFFFFD700)) : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Color swatch
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isUnknownColor ? Colors.grey[300] : _colorFromId(part.colorId),
                  borderRadius: BorderRadius.circular(8),
                  border: part.colorId == 15 ? Border.all(color: Colors.grey[300]!) : null,
                ),
                child: isUnknownColor
                    ? const Center(child: Text('?', style: TextStyle(color: Colors.grey, fontSize: 18)))
                    : null,
              ),
              if (isLowConfidence)
                const Positioned(top: -4, right: -4, child: Text('⚠️', style: TextStyle(fontSize: 14))),
            ],
          ),
          const SizedBox(width: 12),
          // Part info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.partNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  part.colorName ?? (isUnknownColor ? '未知颜色' : ''),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Quantity
          Text('×${part.quantity}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create ResultPage**

Create `app/lib/pages/result/result_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_session.dart';
import '../../models/inventory_part.dart';
import '../../widgets/part_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_theme.dart';

class ResultPage extends StatefulWidget {
  final String sessionId;
  const ResultPage({super.key, required this.sessionId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  InventorySession? _session;
  List<InventoryPart> _parts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<LocalRepository>();
    final session = await repo.getSession(widget.sessionId);
    final parts = await repo.getParts(widget.sessionId);
    setState(() {
      _session = session;
      _parts = parts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('零件清单')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _parts.isEmpty
              ? const EmptyState(icon: Icons.search_off, message: '未识别出零件，试试换个角度或光线')
              : Column(
                  children: [
                    // Summary bar
                    Container(
                      width: double.infinity,
                      color: AppTheme.legoBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '共识别 ${_parts.length} 种零件 · ${_parts.fold(0, (sum, p) => sum + p.quantity)} 件',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Parts list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _parts.length,
                        itemBuilder: (context, index) => PartCard(part: _parts[index]),
                      ),
                    ),
                    // Bottom buttons (disabled in M2)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('补拍'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.edit),
                              label: const Text('编辑'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
```

- [ ] **Step 3: Create widget test**

Create `app/test/widget/result_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/result/result_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('result page shows empty state', (tester) async {
    final repo = LocalRepository(inMemory: true);
    await repo.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: ResultPage(sessionId: 'nonexistent')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('零件清单'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test**

```bash
cd app
flutter test test/widget/result_page_test.dart
```

Expected: 1 passed.

- [ ] **Step 5: Commit**

```bash
git add app/lib/pages/result/ app/lib/widgets/part_card.dart app/test/widget/result_page_test.dart
git commit -m "feat(app): result page with parts list and part cards"
```

---

### Task 9: End-to-end integration test and final verification

**Files:**
- Modify: `app/test/widget/home_page_test.dart` (expand)
- Create: `app/test/widget/full_flow_test.dart`

- [ ] **Step 1: Create full flow integration test**

Create `app/test/widget/full_flow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/main.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/api/api_client.dart';

void main() {
  testWidgets('app starts and shows home page', (tester) async {
    await tester.pumpWidget(const BrickFinderApp());
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('历史清单'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
cd app
flutter analyze
flutter test
```

Expected: `flutter analyze` exit 0. `flutter test` all tests pass.

- [ ] **Step 3: Final commit**

```bash
git add app/
git commit -m "test(app): end-to-end flow test and final verification"
```

---

## Acceptance Criteria for M2

- [ ] `flutter analyze` exit 0 (no warnings or errors)
- [ ] `flutter test` all unit and widget tests pass
- [ ] App starts and shows home page with "拍照识别" button
- [ ] Tapping "拍照识别" navigates to capture page
- [ ] Selecting an image navigates to confirm page
- [ ] Tapping "开始识别" navigates to loading page
- [ ] On recognition success, navigates to result page with parts list
- [ ] Home page persists sessions across app restarts (SQLite)
- [ ] Empty states render correctly on all pages
- [ ] Chinese and English locales both work
- [ ] LEGO-style color scheme applied consistently
