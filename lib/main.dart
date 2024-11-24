import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';
import 'package:http/http.dart' as http;

// 상수 분리
class AppConstants {
  // 크기 관련 상수
  static const overlayPadding = 12.0;
  static const overlayBorderRadius = 20.0;
  static const overlayTextSize = 14.0;
  static const overlayInitialPosition = Offset(20, 100);

  // 졸음 감지 관련 상수
  static const closedEyeThreshold = 0.5;
  static const drowsinessFrameThreshold = 8;
  static const defaultAlertInterval = 3;
  static const nightAlertInterval = 2; // 밤에는 좀더 간격 작게
  static const nightTimeStartHour = 22;
  static const nightTimeEndHour = 5;

  // 진동 및 알람 관련 상수
  static const vibrationInterval = Duration(milliseconds: 100);
  static const volumeChangeDelay = Duration(milliseconds: 100);
  static const dayTimeVolume = 0.7;
  static const nightTimeVolume = 1.0;

  // 초기화 관련 상수
  static const initializationDelay = Duration(milliseconds: 100);
  static const permissionCheckDelay = Duration(milliseconds: 500);

  // 카메라 관련 상수
  static const cameraResolution = ResolutionPreset.low;

  // 카카오 -----
  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoBrown = Color.fromRGBO(56, 35, 36, 1);

  static const buttonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );
  static const defaultSpacing = 16.0;
  static const largeSpacing = 32.0;
  static const avatarRadius = 40.0;
}

// 공통으로 사용되는 스타일
class AppStyles {
  // 오버레이 컨테이너 스타일
  static BoxDecoration overlayDecoration(bool isSleeping) => BoxDecoration(
        color: isSleeping
            ? Colors.red.withOpacity(0.9)
            : Colors.blue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppConstants.overlayBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      );

  // 오버레이 텍스트 스타일
  static const overlayTextStyle = TextStyle(
    color: Colors.white,
    fontSize: AppConstants.overlayTextSize,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  // 알림 다이얼로그 스타일
  static const dialogTitleStyle = TextStyle(
    fontWeight: FontWeight.bold,
  );

  // 버튼 스타일
  static final dialogButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.blue,
  );

  // 카카오---
  static final elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppConstants.kakaoYellow,
    foregroundColor: AppConstants.kakaoBrown,
    padding: AppConstants.buttonPadding,
  );

  static const searchFieldDecoration = InputDecoration(
    labelText: '목적지 입력',
    hintText: '장소명을 입력하세요',
    border: OutlineInputBorder(),
  );
}

// 에러 처리를 위한 유틸리티 클래스
class ErrorHandler {
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// API 응답을 위한 모델 클래스
class Place {
  final String name;
  final String address;
  final String roadAddress;
  final String category;
  final String x;
  final String y;
  final String phone;

  Place({
    required this.name,
    required this.address,
    required this.roadAddress,
    required this.category,
    required this.x,
    required this.y,
    required this.phone,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['place_name'] ?? '',
      address: json['address_name'] ?? '',
      roadAddress: json['road_address_name'] ?? '',
      category: json['category_name'] ?? '',
      x: json['x'] ?? '',
      y: json['y'] ?? '',
      phone: json['phone'] ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'name': name,
      'address': address,
      'road_address': roadAddress,
      'category': category,
      'x': x,
      'y': y,
      'phone': phone,
    };
  }
}

// 최적화된 API 클래스
class KakaoSearchApi {
  // REST API 키
  static const String apiKey = "8938a9bd987f7a76e955d29ed7c4c6ee";
  static KakaoSearchApi? _instance;
  http.Client? _client; // HTTP 클라이언트 재사용

  // private 생성자
  KakaoSearchApi._();

  // 싱글톤 인스턴스 getter
  static KakaoSearchApi get instance {
    _instance ??= KakaoSearchApi._();
    return _instance!;
  }

  Future<List<Place>> searchPlace(String query) async {
    if (query.trim().isEmpty) return const [];

    // 클라이언트가 없거나 닫혀있으면 새로 생성
    _client ??= http.Client();

    try {
      final response = await _client!.get(
        Uri.parse(
            'https://dapi.kakao.com/v2/local/search/keyword.json?query=$query'),
        headers: {'Authorization': 'KakaoAK $apiKey'},
      );
      debugPrint('응답 상태 코드 : ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('검색 결과 데이터 : $data');
        final List<Place> results = (data['documents'] as List)
            .map((place) => Place.fromJson(place))
            .toList();

        return results;
      }
      return const [];
    } catch (e) {
      debugPrint('장소 검색 실패: $e');
      return const [];
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}

// 검색 결과 아이템 위젯
class SearchResultItem extends StatelessWidget {
  final Place place;
  final VoidCallback onNavigate;

  const SearchResultItem({
    super.key,
    required this.place,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(place.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.roadAddress.isNotEmpty
                ? place.roadAddress
                : place.address),
            if (place.category.isNotEmpty)
              Text(
                place.category,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onNavigate,
          style: AppStyles.elevatedButtonStyle,
          child: const Text('길 안내'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Flutter 앱이 백그라운드에서도 실행될 수 있도록 하는 진입점
/// 새로운 isolate에서 실행되므로 @pragma('vm:entry-point') 필요
///
/// 이 어노테이션이 필요한 이유:
/// 1. Flutter 앱이 백그라운드에서 실행될 때, 메인 isolate와 별개의 새로운 isolate가 생성됨
/// 2. 릴리즈 모드에서 tree shaking(사용하지 않는 코드 제거)이 발생할 때 이 함수가 제거되는 것을 방지
/// 3. 컴파일러에게 이 함수가 외부에서 호출될 수 있음을 알림
@pragma('vm:entry-point')
void startCallback() {
  debugPrint('Starting Sleep Detection Service...');

  // 포그라운드 서비스용 핸들러 설정
  // 이 핸들러는 별도의 isolate에서 실행됨
  FlutterForegroundTask.setTaskHandler(SleepDetectionHandler());
}

void main() async {
  /// Flutter 엔진과 위젯 바인딩 초기화
  ///
  /// WidgetsFlutterBinding.ensureInitialized()가 필요한 이유:
  /// 1. Flutter 엔진과 네이티브 플랫폼 간의 바인딩을 초기화
  /// 2. 플러그인 사용, 네이티브 코드 호출, 플랫폼 채널 등을 사용하기 전에 반드시 필요
  /// 3. 특히 main() 함수가 async일 때 필수적
  /// 4. SharedPreferences, 카메라, 파일 시스템 등의 플랫폼 서비스 사용 전에 호출되어야 함
  WidgetsFlutterBinding.ensureInitialized();

  // Kakao SDK 초기화 - 네이티브 앱 키 설정
  KakaoSdk.init(
    nativeAppKey: 'e0d646fb8b530736372d5b725b323514',
  );

  // 포그라운드 서비스 초기화
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'sleep_detection',
      channelName: '졸음 감지 서비스',
      channelDescription: '졸음 감지 서비스가 실행 중입니다.',
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: true,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: true,
      allowWakeLock: true,
    ),
  );

  /// 포그라운드 서비스를 위한 통신 포트 초기화
  ///
  /// FlutterForegroundTask.initCommunicationPort()가 필요한 이유:
  /// 1. 메인 앱과 포그라운드 서비스 간의 통신 채널을 설정
  /// 2. 포그라운드 서비스가 실행 중일 때 데이터를 주고받을 수 있게 함
  /// 3. 서비스 상태 모니터링과 제어를 가능하게 함
  /// 4. 백그라운드 작업과 UI 간의 데이터 동기화를 지원
  FlutterForegroundTask.initCommunicationPort();

  runApp(const MyApp());
}

/// 앱의 루트 위젯
/// MaterialApp을 구성하고 메인 화면을 설정
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // MyApp 클래스는 매우 단순해 보이지만
  // WithForegroundTask 위젯을 사용하기 위해 필요
  // WithForegroundTask 위젯은 앱이 백그라운드로 전환될 때도
  //포그라운드 서비스가 계속 실행되도록 보장하는 래퍼(wrapper) 위젯입니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WithForegroundTask(child: const FaceDetectorView()),
    );
  }
}

////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////

/// 졸음 감지 서비스 핸들러 클래스
/// 백그라운드에서 실행되는 작업을 관리
class SleepDetectionHandler extends TaskHandler {
  // 상태 관리 변수
  bool _isServiceRunning = false;
  bool _isDrowsinessDetected = false;
  DateTime? _lastAlertTime;

  /// 서비스가 시작될 때 호출되는 메서드
  /// @param timestamp - 서비스 시작 시간
  /// @param starter - 서비스 시작 제어 객체
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 서비스 시작 시 필요한 초기화 작업 수행
    debugPrint('Sleep Detection Service Started at: $timestamp');
    _isServiceRunning = true;

    // 서비스 시작 알림
    try {
      // UI에 서비스 시작 알림
      FlutterForegroundTask.sendDataToMain({
        'action': 'service_started',
        'timestamp': timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Service initialization error: $e');
    }
  }

  /// 주기적으로 실행되는 이벤트 핸들러
  /// @param timestamp - 현재 이벤트 발생 시간
  ///  졸음 상태 체크 및 알림 발생 여부 결정
  @override
  void onRepeatEvent(DateTime timestamp) {
    // 주기적으로 실행해야 하는 작업 수행
    if (!_isServiceRunning) return;

    try {
      final isNightTime = timestamp.hour >= AppConstants.nightTimeStartHour ||
          timestamp.hour <= AppConstants.nightTimeEndHour;

      // 졸음이 감지된 경우 알림 발생 여부 체크
      if (_isDrowsinessDetected) {
        final alertInterval = isNightTime
            ? AppConstants.nightAlertInterval
            : AppConstants.defaultAlertInterval;

        // 마지막 알림으로부터 일정 시간이 지났는지 확인
        if (_lastAlertTime == null ||
            timestamp.difference(_lastAlertTime!).inSeconds >= alertInterval) {
          // UI에 알림 요청
          FlutterForegroundTask.sendDataToMain({
            'action': 'trigger_alert',
            'isNightTime': isNightTime,
            'timestamp': timestamp.toIso8601String(),
          });
          _lastAlertTime = timestamp;
          debugPrint('Alert triggered at: $timestamp');
        }
      }
    } catch (e) {
      debugPrint('Repeat event error: $e');
    }
  }

  /// 서비스가 종료될 때 호출되는 메서드
  /// @param timestamp - 서비스 종료 시간
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // 서비스 종료 시 필요한 정리 작업 수행
    debugPrint('Sleep Detection Service Stopped at: $timestamp');
    _isServiceRunning = false;

    try {
      // 서비스 종료 시 알림 중지 요청
      FlutterForegroundTask.sendDataToMain({
        'action': 'stop_alert',
        'timestamp': timestamp.toIso8601String(),
      });

      // 상태 초기화
      _isDrowsinessDetected = false;
      _lastAlertTime = null;
    } catch (e) {
      debugPrint('Service cleanup error: $e');
    }
  }

  /// UI로부터 데이터 수신 시 호출
  /// 졸음 상태 업데이트 등 처리
  /// @param data - 수신된 데이터 객체
  @override
  void onReceiveData(Object? data) {
    // 메인 앱으로부터 받은 데이터 처리
    if (data is Map) {
      try {
        switch (data['action']) {
          case 'update_drowsiness_state':
            // UI에서 감지된 졸음 상태 업데이트
            _isDrowsinessDetected = data['isDrowsy'] as bool;
            debugPrint('Drowsiness state updated: $_isDrowsinessDetected');
            break;

          case 'update_settings':
            // 추가 설정 업데이트 처리
            debugPrint('Settings updated: $data');
            break;

          default:
            debugPrint('Unknown action received: ${data['action']}');
        }
      } catch (e) {
        debugPrint('Data processing error: $e');
      }
    }
  }
}

/// 얼굴 감지 화면 위젯
/// 카메라 피드를 보여주고 졸음 감지 로직을 구현
class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({super.key});

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

/// 얼굴 감지 화면의 상태 관리 클래스
class _FaceDetectorViewState extends State<FaceDetectorView> {
  // ML Kit 얼굴 감지기 초기화
  final FaceDetector _faceDetector =
      FaceDetector(options: FaceDetectorOptions(enableClassification: true));

  // 졸음 감지 관련 상수 및 변수
  int _closedEyeFrameCount = 0; // 눈 감은 프레임 카운터
  bool _canProcess = true; // 이미지 처리 가능 여부
  bool _isBusy = false; // 이미지 처리 중 여부

  // 오버레이 UI 관련 변수
  OverlayEntry? _overlayEntry; // 화면 위에 표시되는 오버레이
  final _isSleepingNotifier = ValueNotifier<bool>(false); // 졸음 상태 알림
  static Offset _overlayPosition =
      AppConstants.overlayInitialPosition; // 오버레이 위치
  bool _isInitialized = false; // 초기화 완료 여부

  // 알람 및 진동 관련 변수
  final AudioPlayer _audioPlayer = AudioPlayer(); // 오디오 플레이어
  bool _isAlarmPlaying = false; // 알람 재생 상태
  DateTime? _lastAlertTime; // 마지막 알림 시간
  bool _isVibratingPlaying = false; // 진동 상태
  late double _originalVolume; // 원래 볼륨을 저장할 변수

  void Function(Object)? _taskCallback; // 콜백 참조 저장용 변수

  // 카카오 로그인 관련 상태 추가
  User? _user;
  bool _isKakaoTalkInstalled = false;
  final TextEditingController _searchController = TextEditingController();

  /// 위젯 초기화 함수
  @override
  void initState() {
    super.initState();
    _initializeServices(); // 서비스 초기화
    _initializeVolume(); // 볼륨 초기화
    _initializeServiceCommunication();
    _initializeKakao(); // 카카오 초기화 추가
  }

  // 카카오 초기화 함수 추가
  Future<void> _initializeKakao() async {
    _isKakaoTalkInstalled = await isKakaoTalkInstalled();
    try {
      _user = await UserApi.instance.me();
      setState(() {});
    } catch (e) {
      debugPrint('Not logged in');
    }
  }

  // 로그인 처리 함수 추가
  Future<void> _handleKakaoLogin() async {
    try {
      if (_isKakaoTalkInstalled) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }
      _user = await UserApi.instance.me();
      setState(() {});
    } catch (e) {
      debugPrint('로그인 실패: $e');
    }
  }

  // 로그아웃 처리 함수 추가
  Future<void> _handleKakaoLogout() async {
    try {
      await UserApi.instance.unlink();
      setState(() {
        _user = null;
      });
    } catch (e) {
      debugPrint('로그아웃 실패: $e');
    }
  }

  /// UI와 서비스 간 통신 초기화
  void _initializeServiceCommunication() {
    // 서비스로부터 메시지 수신을 위한 콜백 설정
    _taskCallback = (Object data) {
      if (data is Map) {
        try {
          switch (data['action']) {
            case 'service_started':
              // 서비스 시작 알림 처리
              debugPrint('Service started at: ${data['timestamp']}');
              break;

            case 'trigger_alert':
              // 알림 요청 처리
              final isNightTime = data['isNightTime'] as bool;
              _triggerAlert(isNightTime);
              break;

            case 'stop_alert':
              // 알림 중지 요청 처리
              _resetState();
              break;
          }
        } catch (e) {
          debugPrint('Error processing service message: $e');
        }
      }
    };

    // 저장된 콜백 함수 등록
    FlutterForegroundTask.addTaskDataCallback(_taskCallback!);
  }

  /// 볼륨 초기화 함수.
  /// 볼륨 변경 리스너 설정
  Future<void> _initializeVolume() async {
    try {
      VolumeController().showSystemUI = false; // 시스템 UI 표시 여부 설정

      // 볼륨 변경 이벤트 리스너 설정
      // 시스템 볼륨이 변경될 때마다 로그 출력
      VolumeController().listener((volume) {
        debugPrint('System volume changed: $volume');
      });
    } catch (e) {
      debugPrint('볼륨 초기화 에러: $e');
    }
  }

  /// 앱 서비스 초기화 함수.
  /// 권한 요청 및 포그라운드 서비스 초기화를 순차적으로 수행
  Future<void> _initializeServices() async {
    try {
      if (Platform.isAndroid) {
        // Android 플랫폼에서 필요한 권한들을 순차적으로 요청
        await _requestPermissionsSequentially();

        // 모든 권한 획득 후 포그라운드 서비스 초기화
        await _initializeForegroundService();
      }

      // 초기화 완료 후 UI 업데이트
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // UI 업데이트 후 오버레이 설정
        // 약간의 지연을 둠으로써 UI가 완전히 빌드된 후 오버레이가 생성되도록 함
        Future.delayed(
          AppConstants.initializationDelay,
          () {
            if (mounted) {
              _overlayEntry?.remove(); // 기존 오버레이 제거
              _createOverlay(); // 새 오버레이 생성
              _showOverlay(false); // 초기 상태로 표시
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Service initialization error: $e');
      // 권한 획득 실패시 사용자에게 설정 다이얼로그 표시
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('권한 필요'),
            content: const Text('앱 실행을 위해 모든 권한이 필요합니다.\n설정에서 권한을 허용해주세요.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings(); // 시스템 설정 화면으로 이동
                },
                child: const Text('설정으로 이동'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initializeServices(); // 권한 요청 재시도
                },
                child: const Text('재시도'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// 권한 순차적 요청 함수.
  /// 카메라, 오디오, 알림, 오버레이, 배터리 권한을 순차적으로 요청
  Future<void> _requestPermissionsSequentially() async {
    if (Platform.isAndroid) {
      // 카메라, 오디오, 알람 권한 요청
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.audio,
        Permission.notification,
      ].request();

      // 권한 획득 실패 시 예외 발생
      if (statuses.values.any((status) => status.isDenied)) {
        throw Exception('Required permissions not granted');
      }

      // 시스템 오버레이 권한 확인 및 요청
      if (!await FlutterForegroundTask.canDrawOverlays) {
        await FlutterForegroundTask.openSystemAlertWindowSettings();
        // 사용자가 설정을 변경할 때까지 대기
        while (!await FlutterForegroundTask.canDrawOverlays) {
          await Future.delayed(AppConstants.permissionCheckDelay);
        }
      }

      // 배터리 최적화 제외 권한 확인 및 요청
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        while (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await Future.delayed(AppConstants.permissionCheckDelay);
        }
      }

      // 모든 권한이 허용되었는지 최종 확인
      if (await FlutterForegroundTask.checkNotificationPermission() !=
              NotificationPermission.granted ||
          !await FlutterForegroundTask.canDrawOverlays ||
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations ||
          !await Permission.camera.isGranted ||
          !await Permission.audio.isGranted) {
        throw Exception('Required permissions not granted');
      }
    }
  }

  /// 포그라운드 서비스 초기화 함수.
  /// 백그라운드에서 앱이 실행될 수 있도록 서비스 설정
  Future<void> _initializeForegroundService() async {
    // 서비스가 실행 중이 아닐 경우에만 시작
    if ((await FlutterForegroundTask.isRunningService)) {
      await FlutterForegroundTask.startService(
        serviceId: 123,
        notificationTitle: '졸음 감지 서비스',
        notificationText: '졸음 감지를 시작합니다.',
        callback: startCallback,
      );
    }
  }

  /// 오버레이 UI 생성 함수.
  /// 화면 위에 표시될 졸음 감지 상태 오버레이를 생성
  void _createOverlay() {
    debugPrint('Creating overlay...');
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: _overlayPosition.dx,
        top: _overlayPosition.dy,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            // 드래그로 위치 이동 가능하도록 설정
            onPanUpdate: (details) {
              _overlayPosition += details.delta;
              _overlayEntry?.markNeedsBuild();
            },
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSleepingNotifier,
              builder: (context, isSleeping, _) => Container(
                padding: const EdgeInsets.all(AppConstants.overlayPadding),
                decoration: AppStyles.overlayDecoration(isSleeping),
                child: Text(
                  isSleeping ? '졸음이 감지됨!' : '졸음 감지중...',
                  style: AppStyles.overlayTextStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 현재 context의 overlay에 접근하여 오버레이 추가
    final overlay = Navigator.of(context).overlay;
    if (overlay != null) {
      debugPrint('Inserting overlay...');
      overlay.insert(_overlayEntry!);
    } else {
      debugPrint('Overlay is null!');
    }
  }

  /// 오버레이 표시 함수.
  /// 졸음 감지 상태에 따라 오버레이 업데이트
  void _showOverlay(bool isSleeping) {
    _isSleepingNotifier.value = isSleeping;
    // 포그라운드 서비스에 상태 업데이트 전송
    FlutterForegroundTask.sendDataToTask({
      'action': 'update_drowsiness_state',
      'isDrowsy': isSleeping,
    });
  }

  /// 이미지 처리 함수.
  /// ML Kit를 사용하여 얼굴을 감지하고 눈 감김 상태를 분석
  Future<void> _processImage(InputImage inputImage) async {
    // 이미지 처리 중이거나 처리할 수 없는 상태면 종료
    if (!_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      // 얼굴 감지 수행
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        // 양쪽 눈의 열림 확률 확인
        final leftEyeOpenProbability = face.leftEyeOpenProbability;
        final rightEyeOpenProbability = face.rightEyeOpenProbability;

        // 눈 감김 상태 분석
        if (leftEyeOpenProbability != null && rightEyeOpenProbability != null) {
          _detectDrowsiness(leftEyeOpenProbability, rightEyeOpenProbability);
        }
      } else {
        _resetState(); // 얼굴이 감지되지 않으면 상태 초기화
      }
    } catch (e) {
      debugPrint('이미지 처리 에러: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// 졸음 감지 함수.
  /// 눈 감김 확률을 기반으로 졸음 상태를 판단
  void _detectDrowsiness(double leftEyeOpenProb, double rightEyeOpenProb) {
    final now = DateTime.now();
    // 야간 시간대(22시 ~ 05시) 여부 확인
    final isNightTime = now.hour >= AppConstants.nightTimeStartHour ||
        now.hour <= AppConstants.nightTimeEndHour;

    // 야간에는 더 민감하게 감지하도록 임계값 조정
    final threshold = isNightTime
        ? AppConstants.closedEyeThreshold * 1.2
        : AppConstants.closedEyeThreshold;

    // 양쪽 눈이 모두 임계값보다 작게 열려있는 경우
    if (leftEyeOpenProb < threshold && rightEyeOpenProb < threshold) {
      _closedEyeFrameCount++;

      // 연속된 프레임 동안 눈을 감고 있는 경우
      if (_closedEyeFrameCount >= AppConstants.drowsinessFrameThreshold) {
        _showOverlay(true); // 서비스에 상태 업데이트
        // 마지막 알림으로부터 일정 시간이 지난 경우에만 알림 발생
        if (_lastAlertTime == null ||
            now.difference(_lastAlertTime!).inSeconds >=
                AppConstants.defaultAlertInterval) {
          _triggerAlert(isNightTime);
          _lastAlertTime = now;
        }
      }
    } else {
      _resetState(); // 눈을 뜨면 상태 초기화
    }
  }

  /// 상태 초기화 함수.
  /// 모든 감지 상태와 알림을 초기화
  void _resetState() {
    _closedEyeFrameCount = 0;
    _stopAlarm();
    _stopVibration();
    _showOverlay(false);
  }

  /// 알림 트리거 함수.
  /// 졸음 감지시 알람과 진동 실행
  Future<void> _triggerAlert(bool isNightTime) async {
    _showOverlay(true); // 졸음 감지 상태 표시

    try {
      // 현재 볼륨 저장
      VolumeController().getVolume().then((volume) {
        _originalVolume = volume;
      });

      // 야간에는 더 큰 볼륨으로 알림
      final volume = isNightTime
          ? AppConstants.nightTimeVolume
          : AppConstants.dayTimeVolume;
      VolumeController().setVolume(volume, showSystemUI: false);

      // 볼륨 설정이 적용되도록 짧은 딜레이 추가
      await Future.delayed(AppConstants.volumeChangeDelay);

      // 알람과 진동 시작
      await _triggerAlarm();
      _triggerVibration();

      // 진동과 알람을 동시에 실행
      // await Future.wait([
      //   _triggerVibration(),
      //   _triggerAlarm(),
      // ]);
    } catch (e) {
      debugPrint('알림 트리거 에러: $e');
    }
  }

  /// 진동 실행 함수.
  /// 연속적인 진동을 발생시킴
  Future<void> _triggerVibration() async {
    if (!_isVibratingPlaying) {
      _isVibratingPlaying = true;
      while (_isVibratingPlaying) {
        await Haptics.vibrate(HapticsType.heavy);
        // 진동 간격 설정
        await Future.delayed(AppConstants.vibrationInterval);
      }
    }
  }

  /// 진동 중지 함수
  void _stopVibration() {
    _isVibratingPlaying = false;
  }

  /// 알람 시작 함수
  Future<void> _triggerAlarm() async {
    if (!_isAlarmPlaying) {
      _isAlarmPlaying = true;
      try {
        // 알람 사운드 파일 재생
        await _audioPlayer.play(AssetSource('alarm.wav'));

        // 알람 반복 재생을 위한 완료 리스너 설정
        _audioPlayer.onPlayerComplete.listen((_) {
          if (_isAlarmPlaying) {
            _audioPlayer.play(AssetSource('alarm.wav')); // 재생 완료 시 다시 재생
          }
        });
      } catch (e) {
        debugPrint('알람 재생 에러: $e');
        _isAlarmPlaying = false;
      }
    }
  }

  /// 알람 중지 함수
  Future<void> _stopAlarm() async {
    if (_isAlarmPlaying) {
      try {
        _isAlarmPlaying = false;
        await _audioPlayer.stop(); // 오디오 재생 중지
        // 원래 볼륨으로 복구
        VolumeController().setVolume(_originalVolume, showSystemUI: false);

        // 볼륨 설정이 적용되도록 짧은 딜레이 추가
        await Future.delayed(AppConstants.volumeChangeDelay);
      } catch (e) {
        debugPrint('알람 중지 에러: $e');
      }
    }
  }

  /// 리소스 해제 함수.
  /// 위젯이 dispose될 때 사용된 리소스들을 정리
  @override
  void dispose() {
    _searchController.dispose();
    _canProcess = false; // 이미지 처리 중지
    _isSleepingNotifier.dispose(); // ValueNotifier 해제
    _faceDetector.close(); // ML Kit 얼굴 감지기 해제
    _audioPlayer.dispose(); // 오디오 플레이어 해제
    _overlayEntry?.remove(); // 오버레이 제거
    _stopVibration(); // 진동 중지

    VolumeController()
        .setVolume(_originalVolume, showSystemUI: false); // 볼륨을 원래대로 복구
    VolumeController().removeListener(); // 볼륨 컨트롤러 리스너 제거
    // 저장된 콜백 함수 제거
    if (_taskCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_taskCallback!);
      _taskCallback = null;
    }
    super.dispose();
  }

  /// UI 빌드 함수
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(
            onImage: _processImage,
            initialCameraLensDirection: CameraLensDirection.front,
          ),
          // 카카오 로그인 UI를 오버레이로 추가
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 로그인 상태에 따른 UI
                    if (_user != null) ...[
                      // 로그인된 경우 목적지 검색 UI 표시
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: AppStyles.searchFieldDecoration,
                              onSubmitted: (value) async {
                                if (value.isNotEmpty) {
                                  final places = await KakaoSearchApi.instance
                                      .searchPlace(value);
                                  if (places.isNotEmpty) {
                                    if (!context.mounted) return;
                                    try {
                                      await NaviApi.instance.navigate(
                                        destination: Location(
                                          name: places.first.name,
                                          x: places.first.x,
                                          y: places.first.y,
                                        ),
                                        option: NaviOption(
                                          coordType: CoordType.wgs84,
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint('네비게이션 실행 실패: $e');
                                    }
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: AppStyles.elevatedButtonStyle,
                              onPressed: _handleKakaoLogout,
                              child: const Text('로그아웃'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // 로그인되지 않은 경우 로그인 버튼 표시
                      GestureDetector(
                        onTap: _handleKakaoLogin,
                        child: Image.asset(
                          'assets/kakao_login_large_narrow.png',
                          height: 90,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32), // 하단 여백
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카메라 뷰 위젯.
/// 카메라 피드를 보여주고 이미지 스트림 처리
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.onImage,
    required this.initialCameraLensDirection,
  });

  final Function(InputImage inputImage) onImage; // 이미지 처리 콜백
  final CameraLensDirection initialCameraLensDirection; // 초기 카메라 방향

  @override
  State<CameraView> createState() => _CameraViewState();
}

/// 카메라 뷰 상태 관리 클래스의 세부 구현
class _CameraViewState extends State<CameraView> {
  static List<CameraDescription> _cameras = []; // 사용 가능한 카메라 목록
  CameraController? _controller; // // 카메라 제어 컨트롤러
  int _cameraIndex = -1; // 현재 사용 중인 카메라 인덱스

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// 카메라 초기화 함수.
  /// 사용 가능한 카메라를 검색하고 초기 설정
  void _initializeCamera() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras(); // 사용 가능한 카메라 목록 가져오기
    }

    // // 지정된 방향(전면)의 카메라 찾기
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startCamera(); // 카메라 시작
    }
  }

  /// 카메라 시작 함수.
  /// 카메라 컨트롤러를 초기화하고 이미지 스트림 시작
  Future<void> _startCamera() async {
    try {
      final camera = _cameras[_cameraIndex];
      _controller = CameraController(
        camera,
        AppConstants.cameraResolution, // 저해상도 설정으로 성능 최적화
        enableAudio: false, // 오디오 비활성화
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // 안드로이드용 이미지 포맷
            : ImageFormatGroup.bgra8888, // iOS용 이미지 포맷
      );

      await _controller?.initialize(); // 카메라 초기화
      if (!mounted) return;

      debugPrint('카메라 초기화 완료: ${camera.lensDirection}');
      await _controller?.startImageStream(_processImage); // 이미지 스트림 시작
      setState(() {}); // UI 업데이트
    } catch (e) {
      debugPrint('카메라 시작 에러: $e');
    }
  }

  /// 이미지 처리 함수.
  /// 카메라에서 받은 이미지를 ML Kit 입력 형식으로 변환
  void _processImage(CameraImage image) {
    if (_controller == null) return;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      // debugPrint('이미지 처리 중: ${image.width}x${image.height}');

      widget.onImage(inputImage); // 변환된 이미지 처리 콜백 실행
    } catch (e) {
      debugPrint('이미지 처리 에러: $e');
    }
  }

  /// 리소스 해제 함수
  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  /// UI 빌드 함수
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          // color: Colors.black, // 배경색을 검정으로 설정
          ),
    );
  }

  /// 디바이스 방향별 회전 각도 매핑
  final _orientations = {
    DeviceOrientation.portraitUp: 0, // 세로 정방향 (기본)
    DeviceOrientation.landscapeLeft: 90, // 왼쪽으로 90도 회전 (가로)
    DeviceOrientation.portraitDown: 180, // 거꾸로 뒤집힘
    DeviceOrientation.landscapeRight: 270, // 오른쪽으로 90도 회전 (가로)
  };

  /// 카메라 이미지를 ML Kit InputImage로 변환하는 함수.
  /// 플랫폼별 이미지 회전 처리 및 포맷 변환 수행
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    try {
      // 현재 카메라 정보 가져오기
      final camera = _cameras[_cameraIndex];
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;

      // 플랫폼별 이미지 회전 처리
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        // 현재 디바이스 방향에 따른 회전 각도 계산
        var rotationCompensation =
            _orientations[_controller!.value.deviceOrientation];
        if (rotationCompensation == null) return null;

        // 전면/후면 카메라에 따른 회전 보정
        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
      if (rotation == null) return null;

      // 이미지 포맷 검증
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null ||
          (Platform.isAndroid && format != InputImageFormat.nv21) ||
          (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

      // 이미지 평면 데이터 검증
      if (image.planes.length != 1) return null;
      final plane = image.planes.first;
      final bytes = plane.bytes;

      //debugPrint('이미지 변환: ${image.width}x${image.height}, 회전: ${rotation.rawValue}');

      // 최종 InputImage 생성 및 반환
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation, // Android에서만 사용
          format: format, // iOS에서만 사용
          bytesPerRow: plane.bytesPerRow, // iOS에서만 사용
        ),
      );
    } catch (e) {
      debugPrint('이미지 변환 에러: $e');
      return null;
    }
  }
}

////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////

class KakaoLoginTest extends StatefulWidget {
  const KakaoLoginTest({super.key});

  @override
  State<KakaoLoginTest> createState() => _KakaoLoginTestState();
}

class _KakaoLoginTestState extends State<KakaoLoginTest> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kakao Login Test',
      // 앱의 전체적인 테마 설정
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.kakaoYellow,
          foregroundColor: AppConstants.kakaoBrown,
          titleTextStyle: TextStyle(
            color: AppConstants.kakaoBrown,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const KakaoLogin(),
    );
  }
}

// 공통으로 사용되는 User 관련 Mixin
mixin UserStateMixin<T extends StatefulWidget> on State<T> {
  User? user;
  bool isLoading = true;

  // 상태 초기화 메서드 추가
  void resetState() {
    if (mounted) {
      setState(() {
        isLoading = true;
        user = null;
      });
    }
  }

  Future<void> loadUserData() async {
    try {
      User loadedUser = await UserApi.instance.me();
      if (mounted) {
        setState(() {
          user = loadedUser;
          isLoading = false;
        });
      }
      debugPrint('사용자 정보 요청 성공'
          '\n회원번호: ${loadedUser.id}'
          '\n닉네임: ${loadedUser.properties}');
    } catch (e) {
      if (mounted) {
        setState(() {
          user = null;
          isLoading = false;
        });
        handleError('사용자 정보를 불러오는데 실패했습니다: $e');
      }
    }
  }

  void handleError(String message) {
    if (!mounted) return;
    ErrorHandler.showError(context, message);
  }

  Widget buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // 공통으로 사용되는 프로필 위젯
  Widget buildUserProfile() {
    return Column(
      children: [
        if (user?.kakaoAccount?.profile?.profileImageUrl != null)
          CircleAvatar(
            radius: AppConstants.avatarRadius,
            backgroundImage: NetworkImage(
              user!.kakaoAccount!.profile!.profileImageUrl!,
            ),
          ),
        const SizedBox(height: AppConstants.defaultSpacing),
        Text(
          '환영합니다, ${user?.kakaoAccount?.profile?.nickname ?? '사용자'}님!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

// 카카오 로그인 화면 위젯
class KakaoLogin extends StatefulWidget {
  const KakaoLogin({super.key});

  @override
  State<KakaoLogin> createState() => _KakaoLoginState();
}

class _KakaoLoginState extends State<KakaoLogin> with UserStateMixin {
  // 카카오톡 앱 설치 여부 상태
  bool _isKakaoTalkInstalled = false;

  @override
  void initState() {
    super.initState();
    _initKakaoTalkInstalled();
    loadUserData(); // 사용자 상태 로드
  }

  // 카카오톡 설치 여부 확인 함수
  Future<void> _initKakaoTalkInstalled() async {
    final installed = await isKakaoTalkInstalled();
    debugPrint('isKakaoTalkInstalled : $installed');
    debugPrint(await KakaoSdk.origin);
    if (mounted) {
      setState(() {
        _isKakaoTalkInstalled = installed;
      });
    }
  }

  // 로그인 처리 함수
  Future<void> _handleLogin() async {
    try {
      if (_isKakaoTalkInstalled) {
        debugPrint('카카오톡 설치됨');
        await _loginWithTalk(); // 카카오톡 설치되어 있으면 카카오톡으로 로그인
      } else {
        await _loginWithKakao(); // 미설치시 카카오 계정으로 로그인
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, '로그인 실패: $e');
      }
    }
  }

  Future<void> _loginWithKakao() async {
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
      debugPrint('카카오계정으로 로그인 성공 ${token.accessToken}');
      await loadUserData(); // 로그인 후 사용자 정보 새로고침
      if (mounted) {
        _moveToLoginDone();
      }
    } catch (e) {
      debugPrint('카카오계정으로 로그인 실패 $e');
      rethrow;
    }
  }

  Future<void> _loginWithTalk() async {
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
      debugPrint('카카오톡으로 로그인 성공 ${token.accessToken}');
      await loadUserData(); // 로그인 후 사용자 정보 새로고침
      if (mounted) {
        _moveToLoginDone();
      }
    } catch (e) {
      debugPrint('카카오톡으로 로그인 실패 $e');
      // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인 시도
      await _loginWithKakao();
    }
  }

  Future<void> _handleLogout() async {
    try {
      await UserApi.instance.unlink();
      if (mounted) {
        setState(() {
          user = null;
        });
        ErrorHandler.showError(context, '로그아웃 성공');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, '로그아웃 실패: $e');
      }
    }
  }

  // 로그인 성공 후 화면 이동
  void _moveToLoginDone() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginDone()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: buildLoadingIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오 로그인 테스트'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null) ...[
              buildUserProfile(),
              const SizedBox(height: AppConstants.defaultSpacing),
              // 길 안내 버튼 목적지 입력(logindone) 위젯으로 넘어감
              ElevatedButton(
                onPressed: _moveToLoginDone,
                style: AppStyles.elevatedButtonStyle,
                child: const Text('길 안내 시작하기'),
              ),
              const SizedBox(height: AppConstants.defaultSpacing),
              // 로그아웃 버튼
              ElevatedButton(
                onPressed: _handleLogout,
                child: const Text('로그아웃'),
              ),
            ] else ...[
              // 로그인 버튼
              GestureDetector(
                onTap: _handleLogin,
                child: Image.asset(
                  'assets/kakao_login_large_narrow.png',
                  height: 90, // 카카오 로그인 버튼의 표준 높이
                  width: 366, // 적절한 너비 설정
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoginDone extends StatefulWidget {
  const LoginDone({super.key});

  @override
  State<LoginDone> createState() => _LoginDoneState();
}

class _LoginDoneState extends State<LoginDone> with UserStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  List<Place> _searchResults = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    KakaoSearchApi.instance.dispose();
    super.dispose();
  }

  // 장소 검색 함수
  Future<void> _searchPlace() async {
    // 검색시 키보드 숨기기
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (_destinationController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await KakaoSearchApi.instance
          .searchPlace(_destinationController.text);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        if (results.isEmpty) {
          handleError('검색 결과가 없습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        handleError('검색 중 오류가 발생했습니다: $e');
      }
    }
  }

  // 선택한 장소로 네비게이션 실행
  Future<void> _navigateToPlace(Place place) async {
    try {
      if (await NaviApi.instance.isKakaoNaviInstalled()) {
        await NaviApi.instance.navigate(
          destination: Location(
            name: place.name,
            x: place.x,
            y: place.y,
          ),
          option: NaviOption(
            coordType: CoordType.wgs84,
          ),
        );
        // 내비게이션 실행 후 상태 갱신
        if (mounted) {
          loadUserData();
        }
      } else {
        await launchBrowserTab(Uri.parse(NaviApi.webNaviInstall));
        handleError('카카오내비 앱이 설치되어 있지 않습니다. 설치 페이지로 이동합니다.');
      }
    } catch (e) {
      handleError('네비게이션 실행 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: buildLoadingIndicator());
    }
    return PopScope(
      canPop: false, // 기본 뒤로가기를 막습니다
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // 뒤로가기 버튼 처리
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const KakaoLogin()),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('로그인 성공'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const KakaoLogin()),
              );
            },
          ),
        ),
        // Stack을 사용하여 배경 터치 영역과 컨텐츠를 분리
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                buildUserProfile(),
                const SizedBox(height: AppConstants.largeSpacing),
                // 검색 입력 필드
                TextField(
                  controller: _destinationController,
                  decoration: AppStyles.searchFieldDecoration.copyWith(
                    suffixIcon: IconButton(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.search),
                      onPressed: _searchPlace,
                    ),
                  ),
                  onSubmitted: (_) => _searchPlace(), // 엔터키로 검색 가능
                  // 키보드의 검색 버튼을 검색 아이콘으로 변경
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: AppConstants.defaultSpacing),
                // 검색 결과 리스트
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return SearchResultItem(
                        place: place,
                        onNavigate: () => _navigateToPlace(place),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
