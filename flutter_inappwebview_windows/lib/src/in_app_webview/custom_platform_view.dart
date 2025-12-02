import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../platform_util.dart';
import '_static_channel.dart';

const Map<String, SystemMouseCursor> _cursors = {
  'none': SystemMouseCursors.none,
  'basic': SystemMouseCursors.basic,
  'click': SystemMouseCursors.click,
  'forbidden': SystemMouseCursors.forbidden,
  'wait': SystemMouseCursors.wait,
  'progress': SystemMouseCursors.progress,
  'contextMenu': SystemMouseCursors.contextMenu,
  'help': SystemMouseCursors.help,
  'text': SystemMouseCursors.text,
  'verticalText': SystemMouseCursors.verticalText,
  'cell': SystemMouseCursors.cell,
  'precise': SystemMouseCursors.precise,
  'move': SystemMouseCursors.move,
  'grab': SystemMouseCursors.grab,
  'grabbing': SystemMouseCursors.grabbing,
  'noDrop': SystemMouseCursors.noDrop,
  'alias': SystemMouseCursors.alias,
  'copy': SystemMouseCursors.copy,
  'disappearing': SystemMouseCursors.disappearing,
  'allScroll': SystemMouseCursors.allScroll,
  'resizeLeftRight': SystemMouseCursors.resizeLeftRight,
  'resizeUpDown': SystemMouseCursors.resizeUpDown,
  'resizeUpLeftDownRight': SystemMouseCursors.resizeUpLeftDownRight,
  'resizeUpRightDownLeft': SystemMouseCursors.resizeUpRightDownLeft,
  'resizeUp': SystemMouseCursors.resizeUp,
  'resizeDown': SystemMouseCursors.resizeDown,
  'resizeLeft': SystemMouseCursors.resizeLeft,
  'resizeRight': SystemMouseCursors.resizeRight,
  'resizeUpLeft': SystemMouseCursors.resizeUpLeft,
  'resizeUpRight': SystemMouseCursors.resizeUpRight,
  'resizeDownLeft': SystemMouseCursors.resizeDownLeft,
  'resizeDownRight': SystemMouseCursors.resizeDownRight,
  'resizeColumn': SystemMouseCursors.resizeColumn,
  'resizeRow': SystemMouseCursors.resizeRow,
  'zoomIn': SystemMouseCursors.zoomIn,
  'zoomOut': SystemMouseCursors.zoomOut,
};

SystemMouseCursor _getCursorByName(String name) =>
    _cursors[name] ?? SystemMouseCursors.basic;

/// Pointer button type
// Order must match InAppWebViewPointerEventKind (see in_app_webview.h)
enum PointerButton { none, primary, secondary, tertiary }

/// Pointer Event kind
// Order must match InAppWebViewPointerEventKind (see in_app_webview.h)
enum InAppWebViewPointerEventKind {
  activate,
  down,
  enter,
  leave,
  up,
  update,
  cancel
}

/// Attempts to translate a button constant such as [kPrimaryMouseButton]
/// to a [PointerButton]
PointerButton _getButton(int value) {
  switch (value) {
    case kPrimaryMouseButton:
      return PointerButton.primary;
    case kSecondaryMouseButton:
      return PointerButton.secondary;
    case kTertiaryButton:
      return PointerButton.tertiary;
    default:
      return PointerButton.none;
  }
}

const MethodChannel _pluginChannel = IN_APP_WEBVIEW_STATIC_CHANNEL;

class CustomFlutterViewControllerValue {
  const CustomFlutterViewControllerValue({
    required this.isInitialized,
  });

  final bool isInitialized;

  CustomFlutterViewControllerValue copyWith({
    bool? isInitialized,
  }) {
    return CustomFlutterViewControllerValue(
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  CustomFlutterViewControllerValue.uninitialized()
      : this(
          isInitialized: false,
        );
}

/// Controls a WebView and provides streams for various change events.
class CustomPlatformViewController
    extends ValueNotifier<CustomFlutterViewControllerValue> {
  Completer<void> _creatingCompleter = Completer<void>();
  int _textureId = 0;
  bool _isDisposed = false;

  Future<void> get ready => _creatingCompleter.future;

  late MethodChannel _methodChannel;
  late EventChannel _eventChannel;
  StreamSubscription? _eventStreamSubscription;

  final StreamController<SystemMouseCursor> _cursorStreamController =
      StreamController<SystemMouseCursor>.broadcast();

  /// A stream reflecting the current cursor style.
  Stream<SystemMouseCursor> get _cursor => _cursorStreamController.stream;

  CustomPlatformViewController()
      : super(CustomFlutterViewControllerValue.uninitialized());

  /// Initializes the underlying platform view.
  Future<void> initialize(
      {Function(int id)? onPlatformViewCreated, dynamic arguments}) async {
    if (_isDisposed) {
      return;
    }
    _textureId = (await _pluginChannel.invokeMethod<int>(
        'createInAppWebView', arguments))!;

    _methodChannel =
        MethodChannel('com.pichillilorenzo/custom_platform_view_$_textureId');
    _eventChannel = EventChannel(
        'com.pichillilorenzo/custom_platform_view_${_textureId}_events');
    _eventStreamSubscription =
        _eventChannel.receiveBroadcastStream().listen((event) {
      final map = event as Map<dynamic, dynamic>;
      switch (map['type']) {
        case 'cursorChanged':
          _cursorStreamController.add(_getCursorByName(map['value']));
          break;
      }
    });

    _methodChannel.setMethodCallHandler((call) {
      throw MissingPluginException('Unknown method ${call.method}');
    });

    value = value.copyWith(isInitialized: true);

    _creatingCompleter.complete();

    onPlatformViewCreated?.call(_textureId);
  }

  @override
  Future<void> dispose() async {
    await _creatingCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      await _eventStreamSubscription?.cancel();
      await _pluginChannel.invokeMethod('dispose', {"id": _textureId});
    }
    super.dispose();
  }

  /// Limits the number of frames per second to the given value.
  Future<void> setFpsLimit([int? maxFps = 0]) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setFpsLimit', maxFps);
  }

  /// Sends a Pointer (Touch) update
  Future<void> _setPointerUpdate(InAppWebViewPointerEventKind kind, int pointer,
      Offset position, double size, double pressure) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerUpdate',
        [pointer, kind.index, position.dx, position.dy, size, pressure]);
  }

  /// Moves the virtual cursor to [position].
  Future<void> _setCursorPos(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel
        .invokeMethod('setCursorPos', [position.dx, position.dy]);
  }

  /// Indicates whether the specified [button] is currently down.
  Future<void> _setPointerButtonState(
      InAppWebViewPointerEventKind kind, PointerButton button) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setPointerButton',
        <String, dynamic>{'kind': kind.index, 'button': button.index});
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(double dx, double dy) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('setScrollDelta', [dx, dy]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(Size size, double scaleFactor) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel
        .invokeMethod('setSize', [size.width, size.height, scaleFactor]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setPosition(Offset position, double scaleFactor) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel
        .invokeMethod('setPosition', [position.dx, position.dy, scaleFactor]);
  }

  /// Sends a keyboard event to the WebView via CDP Input.dispatchKeyEvent.
  /// This allows keyboard input to work even with WS_DISABLED window style.
  Future<void> _sendKeyEvent({
    required String type,
    required String key,
    required String code,
    required int keyCode,
    required bool ctrlKey,
    required bool shiftKey,
    required bool altKey,
    required bool metaKey,
    required bool repeat,
    required int location,
    required bool isKeypad,
    String? text,
  }) async {
    if (_isDisposed) {
      return;
    }
    assert(value.isInitialized);
    return _methodChannel.invokeMethod('sendKeyEvent', <String, dynamic>{
      'type': type,
      'key': key,
      'code': code,
      'keyCode': keyCode,
      'ctrlKey': ctrlKey,
      'shiftKey': shiftKey,
      'altKey': altKey,
      'metaKey': metaKey,
      'repeat': repeat,
      'location': location,
      'isKeypad': isKeypad,
      if (text != null) 'text': text,
    });
  }
}

class CustomPlatformView extends StatefulWidget {
  /// An optional scale factor. Defaults to [FlutterView.devicePixelRatio] for
  /// rendering in native resolution.
  /// Setting this to 1.0 will disable high-DPI support.
  /// This should only be needed to mimic old behavior before high-DPI support
  /// was available.
  final double? scaleFactor;

  /// The [FilterQuality] used for scaling the texture's contents.
  /// Defaults to [FilterQuality.none] as this renders in native resolution
  /// unless specifying a [scaleFactor].
  final FilterQuality filterQuality;

  final dynamic creationParams;

  final Function(int id)? onPlatformViewCreated;

  const CustomPlatformView(
      {this.creationParams,
      this.onPlatformViewCreated,
      this.scaleFactor,
      this.filterQuality = FilterQuality.none});

  @override
  _CustomPlatformViewState createState() => _CustomPlatformViewState();
}

class _CustomPlatformViewState extends State<CustomPlatformView>
    with PlatformUtilListener {
  final GlobalKey _key = GlobalKey();
  final _downButtons = <int, PointerButton>{};

  PointerDeviceKind _pointerKind = PointerDeviceKind.unknown;

  MouseCursor _cursor = SystemMouseCursors.basic;

  final _controller = CustomPlatformViewController();
  final _focusNode = FocusNode();

  StreamSubscription? _cursorSubscription;

  late final AppLifecycleListener _listener;

  PlatformUtil _platformUtil = PlatformUtil.instance();

  @override
  void initState() {
    super.initState();

    _platformUtil.addListener(this);

    _controller.initialize(
        onPlatformViewCreated: (id) {
          widget.onPlatformViewCreated?.call(id);
          setState(() {});
        },
        arguments: widget.creationParams);

    _listener = AppLifecycleListener(onStateChange: (state) {
      if ([AppLifecycleState.resumed, AppLifecycleState.hidden]
          .contains(state)) {
        _reportSurfaceSize();
        _reportWidgetPosition();
      }
    });

    // Report initial surface size and widget position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSurfaceSize();
      _reportWidgetPosition();
    });

    _cursorSubscription = _controller._cursor.listen((cursor) {
      setState(() {
        _cursor = cursor;
      });
    });
  }

  @override
  void onWindowMove() {
    _reportSurfaceSize();
    _reportWidgetPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      canRequestFocus: true,
      debugLabel: "flutter_inappwebview_windows_custom_platform_view",
      onKeyEvent: _handleKeyEvent,
      child: SizedBox.expand(key: _key, child: _buildInner()),
    );
  }

  /// Maps Flutter LogicalKeyboardKey to JavaScript key values for special keys
  static final Map<LogicalKeyboardKey, String> _specialKeyMap = {
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.insert: 'Insert',
    LogicalKeyboardKey.space: ' ',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };

  /// Maps Flutter PhysicalKeyboardKey to DOM code values
  static final Map<PhysicalKeyboardKey, String> _physicalKeyCodeMap = {
    PhysicalKeyboardKey.backspace: 'Backspace',
    PhysicalKeyboardKey.delete: 'Delete',
    PhysicalKeyboardKey.enter: 'Enter',
    PhysicalKeyboardKey.numpadEnter: 'NumpadEnter',
    PhysicalKeyboardKey.tab: 'Tab',
    PhysicalKeyboardKey.escape: 'Escape',
    PhysicalKeyboardKey.arrowUp: 'ArrowUp',
    PhysicalKeyboardKey.arrowDown: 'ArrowDown',
    PhysicalKeyboardKey.arrowLeft: 'ArrowLeft',
    PhysicalKeyboardKey.arrowRight: 'ArrowRight',
    PhysicalKeyboardKey.home: 'Home',
    PhysicalKeyboardKey.end: 'End',
    PhysicalKeyboardKey.pageUp: 'PageUp',
    PhysicalKeyboardKey.pageDown: 'PageDown',
    PhysicalKeyboardKey.insert: 'Insert',
    PhysicalKeyboardKey.space: 'Space',
    PhysicalKeyboardKey.f1: 'F1',
    PhysicalKeyboardKey.f2: 'F2',
    PhysicalKeyboardKey.f3: 'F3',
    PhysicalKeyboardKey.f4: 'F4',
    PhysicalKeyboardKey.f5: 'F5',
    PhysicalKeyboardKey.f6: 'F6',
    PhysicalKeyboardKey.f7: 'F7',
    PhysicalKeyboardKey.f8: 'F8',
    PhysicalKeyboardKey.f9: 'F9',
    PhysicalKeyboardKey.f10: 'F10',
    PhysicalKeyboardKey.f11: 'F11',
    PhysicalKeyboardKey.f12: 'F12',
    // Letter keys
    PhysicalKeyboardKey.keyA: 'KeyA',
    PhysicalKeyboardKey.keyB: 'KeyB',
    PhysicalKeyboardKey.keyC: 'KeyC',
    PhysicalKeyboardKey.keyD: 'KeyD',
    PhysicalKeyboardKey.keyE: 'KeyE',
    PhysicalKeyboardKey.keyF: 'KeyF',
    PhysicalKeyboardKey.keyG: 'KeyG',
    PhysicalKeyboardKey.keyH: 'KeyH',
    PhysicalKeyboardKey.keyI: 'KeyI',
    PhysicalKeyboardKey.keyJ: 'KeyJ',
    PhysicalKeyboardKey.keyK: 'KeyK',
    PhysicalKeyboardKey.keyL: 'KeyL',
    PhysicalKeyboardKey.keyM: 'KeyM',
    PhysicalKeyboardKey.keyN: 'KeyN',
    PhysicalKeyboardKey.keyO: 'KeyO',
    PhysicalKeyboardKey.keyP: 'KeyP',
    PhysicalKeyboardKey.keyQ: 'KeyQ',
    PhysicalKeyboardKey.keyR: 'KeyR',
    PhysicalKeyboardKey.keyS: 'KeyS',
    PhysicalKeyboardKey.keyT: 'KeyT',
    PhysicalKeyboardKey.keyU: 'KeyU',
    PhysicalKeyboardKey.keyV: 'KeyV',
    PhysicalKeyboardKey.keyW: 'KeyW',
    PhysicalKeyboardKey.keyX: 'KeyX',
    PhysicalKeyboardKey.keyY: 'KeyY',
    PhysicalKeyboardKey.keyZ: 'KeyZ',
    // Number keys
    PhysicalKeyboardKey.digit0: 'Digit0',
    PhysicalKeyboardKey.digit1: 'Digit1',
    PhysicalKeyboardKey.digit2: 'Digit2',
    PhysicalKeyboardKey.digit3: 'Digit3',
    PhysicalKeyboardKey.digit4: 'Digit4',
    PhysicalKeyboardKey.digit5: 'Digit5',
    PhysicalKeyboardKey.digit6: 'Digit6',
    PhysicalKeyboardKey.digit7: 'Digit7',
    PhysicalKeyboardKey.digit8: 'Digit8',
    PhysicalKeyboardKey.digit9: 'Digit9',
    // Punctuation
    PhysicalKeyboardKey.minus: 'Minus',
    PhysicalKeyboardKey.equal: 'Equal',
    PhysicalKeyboardKey.bracketLeft: 'BracketLeft',
    PhysicalKeyboardKey.bracketRight: 'BracketRight',
    PhysicalKeyboardKey.backslash: 'Backslash',
    PhysicalKeyboardKey.semicolon: 'Semicolon',
    PhysicalKeyboardKey.quote: 'Quote',
    PhysicalKeyboardKey.backquote: 'Backquote',
    PhysicalKeyboardKey.comma: 'Comma',
    PhysicalKeyboardKey.period: 'Period',
    PhysicalKeyboardKey.slash: 'Slash',
    // Modifier keys
    PhysicalKeyboardKey.shiftLeft: 'ShiftLeft',
    PhysicalKeyboardKey.shiftRight: 'ShiftRight',
    PhysicalKeyboardKey.controlLeft: 'ControlLeft',
    PhysicalKeyboardKey.controlRight: 'ControlRight',
    PhysicalKeyboardKey.altLeft: 'AltLeft',
    PhysicalKeyboardKey.altRight: 'AltRight',
    PhysicalKeyboardKey.metaLeft: 'MetaLeft',
    PhysicalKeyboardKey.metaRight: 'MetaRight',
    PhysicalKeyboardKey.capsLock: 'CapsLock',
    // Numpad keys
    PhysicalKeyboardKey.numpad0: 'Numpad0',
    PhysicalKeyboardKey.numpad1: 'Numpad1',
    PhysicalKeyboardKey.numpad2: 'Numpad2',
    PhysicalKeyboardKey.numpad3: 'Numpad3',
    PhysicalKeyboardKey.numpad4: 'Numpad4',
    PhysicalKeyboardKey.numpad5: 'Numpad5',
    PhysicalKeyboardKey.numpad6: 'Numpad6',
    PhysicalKeyboardKey.numpad7: 'Numpad7',
    PhysicalKeyboardKey.numpad8: 'Numpad8',
    PhysicalKeyboardKey.numpad9: 'Numpad9',
    PhysicalKeyboardKey.numpadDecimal: 'NumpadDecimal',
    PhysicalKeyboardKey.numpadAdd: 'NumpadAdd',
    PhysicalKeyboardKey.numpadSubtract: 'NumpadSubtract',
    PhysicalKeyboardKey.numpadMultiply: 'NumpadMultiply',
    PhysicalKeyboardKey.numpadDivide: 'NumpadDivide',
  };

  /// Maps LogicalKeyboardKey to Windows Virtual Key codes
  static final Map<LogicalKeyboardKey, int> _windowsVkCodeMap = {
    LogicalKeyboardKey.backspace: 0x08,
    LogicalKeyboardKey.tab: 0x09,
    LogicalKeyboardKey.enter: 0x0D,
    LogicalKeyboardKey.numpadEnter: 0x0D,
    LogicalKeyboardKey.shiftLeft: 0x10,
    LogicalKeyboardKey.shiftRight: 0x10,
    LogicalKeyboardKey.controlLeft: 0x11,
    LogicalKeyboardKey.controlRight: 0x11,
    LogicalKeyboardKey.altLeft: 0x12,
    LogicalKeyboardKey.altRight: 0x12,
    LogicalKeyboardKey.capsLock: 0x14,
    LogicalKeyboardKey.escape: 0x1B,
    LogicalKeyboardKey.space: 0x20,
    LogicalKeyboardKey.pageUp: 0x21,
    LogicalKeyboardKey.pageDown: 0x22,
    LogicalKeyboardKey.end: 0x23,
    LogicalKeyboardKey.home: 0x24,
    LogicalKeyboardKey.arrowLeft: 0x25,
    LogicalKeyboardKey.arrowUp: 0x26,
    LogicalKeyboardKey.arrowRight: 0x27,
    LogicalKeyboardKey.arrowDown: 0x28,
    LogicalKeyboardKey.insert: 0x2D,
    LogicalKeyboardKey.delete: 0x2E,
    // 0-9 keys
    LogicalKeyboardKey.digit0: 0x30,
    LogicalKeyboardKey.digit1: 0x31,
    LogicalKeyboardKey.digit2: 0x32,
    LogicalKeyboardKey.digit3: 0x33,
    LogicalKeyboardKey.digit4: 0x34,
    LogicalKeyboardKey.digit5: 0x35,
    LogicalKeyboardKey.digit6: 0x36,
    LogicalKeyboardKey.digit7: 0x37,
    LogicalKeyboardKey.digit8: 0x38,
    LogicalKeyboardKey.digit9: 0x39,
    // A-Z keys (0x41-0x5A)
    LogicalKeyboardKey.keyA: 0x41,
    LogicalKeyboardKey.keyB: 0x42,
    LogicalKeyboardKey.keyC: 0x43,
    LogicalKeyboardKey.keyD: 0x44,
    LogicalKeyboardKey.keyE: 0x45,
    LogicalKeyboardKey.keyF: 0x46,
    LogicalKeyboardKey.keyG: 0x47,
    LogicalKeyboardKey.keyH: 0x48,
    LogicalKeyboardKey.keyI: 0x49,
    LogicalKeyboardKey.keyJ: 0x4A,
    LogicalKeyboardKey.keyK: 0x4B,
    LogicalKeyboardKey.keyL: 0x4C,
    LogicalKeyboardKey.keyM: 0x4D,
    LogicalKeyboardKey.keyN: 0x4E,
    LogicalKeyboardKey.keyO: 0x4F,
    LogicalKeyboardKey.keyP: 0x50,
    LogicalKeyboardKey.keyQ: 0x51,
    LogicalKeyboardKey.keyR: 0x52,
    LogicalKeyboardKey.keyS: 0x53,
    LogicalKeyboardKey.keyT: 0x54,
    LogicalKeyboardKey.keyU: 0x55,
    LogicalKeyboardKey.keyV: 0x56,
    LogicalKeyboardKey.keyW: 0x57,
    LogicalKeyboardKey.keyX: 0x58,
    LogicalKeyboardKey.keyY: 0x59,
    LogicalKeyboardKey.keyZ: 0x5A,
    LogicalKeyboardKey.metaLeft: 0x5B,
    LogicalKeyboardKey.metaRight: 0x5C,
    // Numpad
    LogicalKeyboardKey.numpad0: 0x60,
    LogicalKeyboardKey.numpad1: 0x61,
    LogicalKeyboardKey.numpad2: 0x62,
    LogicalKeyboardKey.numpad3: 0x63,
    LogicalKeyboardKey.numpad4: 0x64,
    LogicalKeyboardKey.numpad5: 0x65,
    LogicalKeyboardKey.numpad6: 0x66,
    LogicalKeyboardKey.numpad7: 0x67,
    LogicalKeyboardKey.numpad8: 0x68,
    LogicalKeyboardKey.numpad9: 0x69,
    LogicalKeyboardKey.numpadMultiply: 0x6A,
    LogicalKeyboardKey.numpadAdd: 0x6B,
    LogicalKeyboardKey.numpadSubtract: 0x6D,
    LogicalKeyboardKey.numpadDecimal: 0x6E,
    LogicalKeyboardKey.numpadDivide: 0x6F,
    // Function keys
    LogicalKeyboardKey.f1: 0x70,
    LogicalKeyboardKey.f2: 0x71,
    LogicalKeyboardKey.f3: 0x72,
    LogicalKeyboardKey.f4: 0x73,
    LogicalKeyboardKey.f5: 0x74,
    LogicalKeyboardKey.f6: 0x75,
    LogicalKeyboardKey.f7: 0x76,
    LogicalKeyboardKey.f8: 0x77,
    LogicalKeyboardKey.f9: 0x78,
    LogicalKeyboardKey.f10: 0x79,
    LogicalKeyboardKey.f11: 0x7A,
    LogicalKeyboardKey.f12: 0x7B,
    // OEM keys (US keyboard layout)
    LogicalKeyboardKey.semicolon: 0xBA,
    LogicalKeyboardKey.equal: 0xBB,
    LogicalKeyboardKey.comma: 0xBC,
    LogicalKeyboardKey.minus: 0xBD,
    LogicalKeyboardKey.period: 0xBE,
    LogicalKeyboardKey.slash: 0xBF,
    LogicalKeyboardKey.backquote: 0xC0,
    LogicalKeyboardKey.bracketLeft: 0xDB,
    LogicalKeyboardKey.backslash: 0xDC,
    LogicalKeyboardKey.bracketRight: 0xDD,
    LogicalKeyboardKey.quote: 0xDE,
  };

  /// Checks if a physical key is on the numpad
  static bool _isNumpadKey(PhysicalKeyboardKey key) {
    return key == PhysicalKeyboardKey.numpad0 ||
        key == PhysicalKeyboardKey.numpad1 ||
        key == PhysicalKeyboardKey.numpad2 ||
        key == PhysicalKeyboardKey.numpad3 ||
        key == PhysicalKeyboardKey.numpad4 ||
        key == PhysicalKeyboardKey.numpad5 ||
        key == PhysicalKeyboardKey.numpad6 ||
        key == PhysicalKeyboardKey.numpad7 ||
        key == PhysicalKeyboardKey.numpad8 ||
        key == PhysicalKeyboardKey.numpad9 ||
        key == PhysicalKeyboardKey.numpadDecimal ||
        key == PhysicalKeyboardKey.numpadAdd ||
        key == PhysicalKeyboardKey.numpadSubtract ||
        key == PhysicalKeyboardKey.numpadMultiply ||
        key == PhysicalKeyboardKey.numpadDivide ||
        key == PhysicalKeyboardKey.numpadEnter;
  }

  /// Gets the keyboard location for CDP (0=standard, 1=left, 2=right, 3=numpad)
  static int _getKeyLocation(PhysicalKeyboardKey key) {
    if (_isNumpadKey(key)) return 3;
    if (key == PhysicalKeyboardKey.shiftLeft ||
        key == PhysicalKeyboardKey.controlLeft ||
        key == PhysicalKeyboardKey.altLeft ||
        key == PhysicalKeyboardKey.metaLeft) return 1;
    if (key == PhysicalKeyboardKey.shiftRight ||
        key == PhysicalKeyboardKey.controlRight ||
        key == PhysicalKeyboardKey.altRight ||
        key == PhysicalKeyboardKey.metaRight) return 2;
    return 0;
  }

  /// Handles keyboard events and forwards them to the WebView via CDP Input.dispatchKeyEvent.
  /// This allows keyboard input to work even with WS_DISABLED window style,
  /// while keeping focus on the Flutter window (no app lifecycle changes).
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_controller.value.isInitialized) {
      return KeyEventResult.ignored;
    }

    String type;
    if (event is KeyDownEvent) {
      type = 'keydown';
    } else if (event is KeyUpEvent) {
      type = 'keyup';
    } else if (event is KeyRepeatEvent) {
      type = 'keydown';
    } else {
      return KeyEventResult.ignored;
    }

    // Get the key value - check special keys first, then character, then label
    String key;
    if (_specialKeyMap.containsKey(event.logicalKey)) {
      key = _specialKeyMap[event.logicalKey]!;
    } else if (event.character != null && event.character!.isNotEmpty) {
      key = event.character!;
    } else {
      key = event.logicalKey.keyLabel;
    }

    // Get the DOM code value from physical key
    String code;
    if (_physicalKeyCodeMap.containsKey(event.physicalKey)) {
      code = _physicalKeyCodeMap[event.physicalKey]!;
    } else {
      // Fallback: use debugName and hope it matches DOM code format
      code = event.physicalKey.debugName ?? '';
    }

    // Get the Windows virtual key code from our mapping
    int keyCode;
    if (_windowsVkCodeMap.containsKey(event.logicalKey)) {
      keyCode = _windowsVkCodeMap[event.logicalKey]!;
    } else {
      // Fallback: use lower bits of keyId (works for some keys)
      keyCode = event.logicalKey.keyId & 0xFFFF;
    }

    // Check modifier keys
    bool ctrlKey = HardwareKeyboard.instance.isControlPressed;
    bool shiftKey = HardwareKeyboard.instance.isShiftPressed;
    bool altKey = HardwareKeyboard.instance.isAltPressed;
    bool metaKey = HardwareKeyboard.instance.isMetaPressed;
    bool repeat = event is KeyRepeatEvent;

    // Get key location and numpad status
    int location = _getKeyLocation(event.physicalKey);
    bool isKeypad = _isNumpadKey(event.physicalKey);

    // Get the text to insert (character with modifiers applied)
    // This is the actual character that should be typed
    String? text = event.character;

    unawaited(_controller._sendKeyEvent(
      type: type,
      key: key,
      code: code,
      keyCode: keyCode,
      ctrlKey: ctrlKey,
      shiftKey: shiftKey,
      altKey: altKey,
      metaKey: metaKey,
      repeat: repeat,
      location: location,
      isKeypad: isKeypad,
      text: text,
    ));

    // Return handled to prevent the event from propagating further
    return KeyEventResult.handled;
  }

  Widget _buildInner() {
    return NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          _reportSurfaceSize();
          _reportWidgetPosition();
          return true;
        },
        child: SizeChangedLayoutNotifier(
            child: _controller.value.isInitialized
                ? Listener(
                    onPointerHover: (ev) {
                      // ev.kind is for whatever reason not set to touch
                      // even on touch input
                      if (_pointerKind == PointerDeviceKind.touch) {
                        // Ignoring hover events on touch for now
                        return;
                      }
                      _controller._setCursorPos(ev.localPosition);
                    },
                    onPointerDown: (ev) {
                      _reportSurfaceSize();
                      _reportWidgetPosition();

                      if (!_focusNode.hasFocus) {
                        _focusNode.requestFocus();
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (!_focusNode.hasFocus) {
                            _focusNode.requestFocus();
                          }
                        });
                      }

                      _pointerKind = ev.kind;
                      if (ev.kind == PointerDeviceKind.touch) {
                        _controller._setPointerUpdate(
                            InAppWebViewPointerEventKind.down,
                            ev.pointer,
                            ev.localPosition,
                            ev.size,
                            ev.pressure);
                        return;
                      }
                      final button = _getButton(ev.buttons);
                      _downButtons[ev.pointer] = button;
                      _controller._setPointerButtonState(
                          InAppWebViewPointerEventKind.down, button);
                    },
                    onPointerUp: (ev) {
                      _pointerKind = ev.kind;
                      if (ev.kind == PointerDeviceKind.touch) {
                        _controller._setPointerUpdate(
                            InAppWebViewPointerEventKind.up,
                            ev.pointer,
                            ev.localPosition,
                            ev.size,
                            ev.pressure);
                        return;
                      }
                      final button = _downButtons.remove(ev.pointer);
                      if (button != null) {
                        _controller._setPointerButtonState(
                            InAppWebViewPointerEventKind.up, button);
                      }
                    },
                    onPointerCancel: (ev) {
                      _pointerKind = ev.kind;
                      final button = _downButtons.remove(ev.pointer);
                      if (button != null) {
                        _controller._setPointerButtonState(
                            InAppWebViewPointerEventKind.cancel, button);
                      }
                    },
                    onPointerMove: (ev) {
                      _pointerKind = ev.kind;
                      if (ev.kind == PointerDeviceKind.touch) {
                        _controller._setPointerUpdate(
                            InAppWebViewPointerEventKind.update,
                            ev.pointer,
                            ev.localPosition,
                            ev.size,
                            ev.pressure);
                      } else {
                        _controller._setCursorPos(ev.localPosition);
                      }
                    },
                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent) {
                        _controller._setScrollDelta(
                            -signal.scrollDelta.dx, -signal.scrollDelta.dy);
                      }
                    },
                    onPointerPanZoomUpdate: (ev) {
                      _controller._setScrollDelta(
                          ev.panDelta.dx, ev.panDelta.dy);
                    },
                    child: MouseRegion(
                        cursor: _cursor,
                        onEnter: (ev) {
                          final button = _getButton(ev.buttons);
                          _controller._setPointerButtonState(
                              InAppWebViewPointerEventKind.enter, button);
                        },
                        onExit: (ev) {
                          final button = _getButton(ev.buttons);
                          _controller._setPointerButtonState(
                              InAppWebViewPointerEventKind.leave, button);
                        },
                        child: Texture(
                          textureId: _controller._textureId,
                          filterQuality: widget.filterQuality,
                        )),
                  )
                : const SizedBox()));
  }

  void _reportSurfaceSize() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      unawaited(_controller._setSize(
          box.size, widget.scaleFactor ?? window.devicePixelRatio));
    }
  }

  void _reportWidgetPosition() async {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      final position = box.localToGlobal(Offset.zero);
      unawaited(_controller._setPosition(
          position, widget.scaleFactor ?? window.devicePixelRatio));
    }
  }

  @override
  void dispose() {
    super.dispose();
    _platformUtil.removeListener(this);
    _cursorSubscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _listener.dispose();
  }
}
