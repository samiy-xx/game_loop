/*
  Copyright (C) 2012 John McCutchan <john@johnmccutchan.com>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

part of game_loop;

/** Called once per draw frame. Draw in here. */
typedef void GameLoopRenderFunction(GameLoop gameLoop);

/** Called once per update frame. Update game state here. */
typedef void GameLoopUpdateFunction(GameLoop gameLoop);

/** Called whenever the element is resized. */
typedef void GameLoopResizeFunction(GameLoop gameLoop);

/** Called whenever the element moves between fullscreen and non-fullscreen
 * mode.
 */
typedef void GameLoopFullscreenChangeFunction(GameLoop gameLoop);

/** Called whenever the element moves between locking the pointer and
 * not locking the pointer.
 */
typedef void GameLoopPointerLockChangeFunction(GameLoop gameLoop);

/** The game loop */
class GameLoop {
  final Element element;
  bool _initialized = false;
  bool _interrupt = false;
  int _frameCounter = 0;
  double _previousFrameTime;
  double _frameTime = 0.0;
  double _dt;

  /** Any wall time in excess of maxTimeDelta is dropped. */
  double maxTimeDelta = 1.0 / 30.0;

  /** The time between onUpdate calls */
  double gameUpdateTimeDelta = 1.0 / 60.0;

  /** Width of game display [Element] */
  int get width => element.width;
  /** Height of game display [Element] */
  int get height => element.height;

  /** Frame counter value. Incremented once per frame. */
  int get frame => _frameCounter;
  /** Frame time value in seconds. */
  double get frameTime => _frameTime;
  /** Time elapsed since previous frame */
  double get dt => _dt;

  static double timeStampToSeconds(timeStamp) => timeStamp / 1000.0;
  static double milliseconds(int x) => x / 1000.0;
  static double seconds(int x) => x.toDouble();
  static double minutes(int x) => x.toDouble() * 60.0;

  /** Current time. */
  double get time => timeStampToSeconds(new Date.now().millisecondsSinceEpoch);

  GameLoopPointerLock _pointerLock;
  GameLoopPointerLock get pointerLock => _pointerLock;

  GameLoopKeyboard _keyboard;
  /** Keyboard. */
  GameLoopKeyboard get keyboard => _keyboard;
  GameLoopMouse _mouse;
  /** Mouse. */
  GameLoopMouse get mouse => _mouse;
  GameLoopGamepad _gamepad0;
  /** Gamepad #0. */
  GameLoopGamepad get gamepad0 => _gamepad0;

  /** Construct a new game loop attaching it to [element] */
  GameLoop(this.element) {
    _keyboard = new GameLoopKeyboard(this);
    _mouse = new GameLoopMouse(this);
    _gamepad0 = new GameLoopGamepad(this);
    _pointerLock = new GameLoopPointerLock(this);
  }

  void _processInputEvents() {
    for (KeyboardEvent keyboardEvent in _keyboardEvents) {
      GameLoopDigitalButtonEvent event;
      bool down = keyboardEvent.type == "keydown";
      double time = timeStampToSeconds(keyboardEvent.timeStamp);
      int buttonId = keyboardEvent.keyCode;
      event = new GameLoopDigitalButtonEvent(buttonId, down, frame, time);
      _keyboard.digitalButtonEvent(event);
    }
    _keyboardEvents.clear();
    mouse._resetAccumulators();
    for (MouseEvent mouseEvent in _mouseEvents) {
      bool moveEvent = mouseEvent.type == 'mousemove';
      bool down = mouseEvent.type == 'mousedown';
      double time = timeStampToSeconds(mouseEvent.timeStamp);
      if (moveEvent) {
        int x = mouseEvent.offsetX;
        int y = mouseEvent.offsetY;
        int dx = mouseEvent.webkitMovementX;
        int dy = mouseEvent.webkitMovementY;
        GameLoopMouseEvent event = new GameLoopMouseEvent(x, y, dx, dy,
                                                          time, frame);
        _mouse.gameLoopMouseEvent(event);
      } else {
        GameLoopDigitalButtonEvent event;
        int buttonId = mouseEvent.button;
        event = new GameLoopDigitalButtonEvent(buttonId, down, frame, time);
        _mouse.digitalButtonEvent(event);
      }
    }
    _mouseEvents.clear();
  }

  void _processTimers() {
    for (GameLoopTimer timer in _timers) {
      timer._update(_dt);
    }
    for (int i = _timers.length-1; i >= 0; i--) {
      int lastElement = _timers.length-1;
      if (_timers[i]._dead) {
        if (i != lastElement) {
          // Swap into i's place.
          _timers[i] = _timers[lastElement];
        }
        _timers.removeLast();
      }
    }
  }

  void _requestAnimationFrame(num _) {
    if (_previousFrameTime == null) {
      _frameTime = time;
      _previousFrameTime = _frameTime;
      _processInputEvents();
      window.requestAnimationFrame(_requestAnimationFrame);
      return;
    }
    if (_interrupt == true) {
      return;
    }
    window.requestAnimationFrame(_requestAnimationFrame);
    _frameCounter++;
    _previousFrameTime = _frameTime;
    _frameTime = time;
    double timeDelta = _frameTime - _previousFrameTime;
    if (timeDelta > maxTimeDelta) {
      // If the animation frame callback was paused we may end up with
      // a huge time delta. Clamp it to something reasonable.
      timeDelta = maxTimeDelta;
    }
    // TODO(johnmccutchan): Process input events in update loop.
    _processInputEvents();
    while (timeDelta > gameUpdateTimeDelta) {
      _dt = gameUpdateTimeDelta;
      _processTimers();
      if (onUpdate != null) {
        onUpdate(this);
      }
      timeDelta -= gameUpdateTimeDelta;
    }
    if (onRender != null) {
      onRender(this);
    }
  }

  void _fullscreenChange(Event _) {
    if (onFullscreenChange == null) {
      return;
    }
    onFullscreenChange(this);
  }

  void _fullscreenError(Event _) {
    if (onFullscreenChange == null) {
      return;
    }
    onFullscreenChange(this);
  }

  final List<KeyboardEvent> _keyboardEvents = new List<KeyboardEvent>();
  void _keyDown(KeyboardEvent event) {
    _keyboardEvents.add(event);
  }

  void _keyUp(KeyboardEvent event) {
    _keyboardEvents.add(event);
  }

  final List<MouseEvent> _mouseEvents = new List<MouseEvent>();
  void _mouseDown(MouseEvent event) {
    _mouseEvents.add(event);
  }

  void _mouseUp(MouseEvent event) {
    _mouseEvents.add(event);
  }

  void _mouseMove(MouseEvent event) {
    _mouseEvents.add(event);
  }

  void _resize(Event _) {
    if (onResize != null) {
      onResize(this);
    }
  }

  /** Start the game loop. */
  void start() {
    if (_initialized == false) {
      document.on.fullscreenError.add(_fullscreenError);
      document.on.fullscreenChange.add(_fullscreenChange);
      window.on.keyDown.add(_keyDown);
      window.on.keyUp.add(_keyUp);
      window.on.resize.add(_resize);
      element.on.mouseMove.add(_mouseMove);
      element.on.mouseDown.add(_mouseDown);
      element.on.mouseUp.add(_mouseUp);
      _initialized = true;
    }
    _interrupt = false;
    window.requestAnimationFrame(_requestAnimationFrame);
  }

  /** Stop the game loop. */
  void stop() {
    _interrupt = true;
  }

  /** Is the element being displayed full screen? */
  bool get isFullscreen => document.webkitFullscreenElement == element;

  /** Enable or disable fullscreen display of the element. */
  void enableFullscreen(bool enable) {
    if (enable) {
      element.webkitRequestFullscreen();
      return;
    }
    element.webkitCancelFullScreen();
  }

  final List<GameLoopTimer> _timers = new List<GameLoopTimer>();

  /** Add a new timer which calls [callback] in [delay] seconds. */
  GameLoopTimer addTimer(GameLoopTimerFunction callback, double delay) {
    GameLoopTimer timer = new GameLoopTimer._internal(this, delay, callback);
    _timers.add(timer);
    return timer;
  }

  /** Clear all existing timers. */
  void clearTimers() {
    _timers.clear();
  }

  /** Called once per game logic frame. */
  GameLoopUpdateFunction onUpdate;
  /** Called per draw frame. */
  GameLoopRenderFunction onRender;
  /** Called when element is resized. */
  GameLoopResizeFunction onResize;
  /** Called when element moves between fullscreen and non-fullscreen mode. */
  GameLoopFullscreenChangeFunction onFullscreenChange;
  /** Called when the element moves between locking the pointer and not
   *  locking the pointer.
   */
  GameLoopPointerLockChangeFunction onPointerLockChange;
}