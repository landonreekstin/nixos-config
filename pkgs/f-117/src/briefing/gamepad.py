"""Xbox (or any SDL-recognised) controller support.

Qt 6 has no gamepad module, so this uses pygame's SDL GameController API, which
gives every controller the same Xbox-style button names. pygame needs a "display"
to deliver events, so it gets SDL's invisible dummy one, and background events are
allowed so the controller still works when SDL's (non-existent) window isn't focused.

Button map (shown in the app's hint bar):
    D-pad / left stick   move
    A                    open / select
    B                    back
    X                    Headlines <-> Briefing
    Y                    See all (or Brief me in briefing view)
    LB / RB              previous / next page
    LT / RT              scroll a screen left / right
    right stick          scroll left / right
    Menu (≡)             refresh feeds
    View (⧉)             My Focus
"""

import os
import warnings

from PyQt6.QtCore import QObject, QTimer, pyqtSignal

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")

warnings.filterwarnings("ignore", message=".*avx2.*")  # harmless pygame build notice

try:
    import pygame
    from pygame._sdl2 import controller as sdl_controller
except Exception:  # no pygame: the app simply has no controller support
    pygame = None

DEADZONE = 0.55
REPEAT_FIRST, REPEAT_NEXT = 380, 130  # ms, when a direction is held


class Gamepad(QObject):
    action = pyqtSignal(str)
    connected = pyqtSignal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.pads = {}
        self.held = None  # direction currently held on stick / d-pad
        self.scroll = 0.0  # right stick x
        self.ok = False
        if pygame is None:
            return
        try:
            pygame.display.init()
            sdl_controller.init()
        except Exception:
            return
        self.ok = True
        self.buttons = {
            pygame.CONTROLLER_BUTTON_A: "activate",
            pygame.CONTROLLER_BUTTON_B: "back",
            pygame.CONTROLLER_BUTTON_X: "toggle_mode",
            pygame.CONTROLLER_BUTTON_Y: "secondary",
            pygame.CONTROLLER_BUTTON_LEFTSHOULDER: "prev_page",
            pygame.CONTROLLER_BUTTON_RIGHTSHOULDER: "next_page",
            pygame.CONTROLLER_BUTTON_START: "refresh",
            pygame.CONTROLLER_BUTTON_BACK: "focus_page",
        }
        self.dpad = {
            pygame.CONTROLLER_BUTTON_DPAD_UP: "up",
            pygame.CONTROLLER_BUTTON_DPAD_DOWN: "down",
            pygame.CONTROLLER_BUTTON_DPAD_LEFT: "left",
            pygame.CONTROLLER_BUTTON_DPAD_RIGHT: "right",
        }
        self.trigger_down = {"lt": False, "rt": False}
        for i in range(sdl_controller.get_count()):
            self._open(i)
        self.poll_timer = QTimer(self, interval=16, timeout=self.poll)
        self.poll_timer.start()
        self.repeat = QTimer(self, singleShot=True, timeout=self._repeat)

    def _open(self, index):
        try:
            pad = sdl_controller.Controller(index)
        except Exception:
            return
        self.pads[pad.id] = pad
        self.connected.emit(True)

    def any_connected(self):
        return bool(self.pads)

    def _press(self, direction):
        if direction != self.held:
            self.held = direction
            if direction:
                self.action.emit(direction)
                self.repeat.start(REPEAT_FIRST)
            else:
                self.repeat.stop()

    def _repeat(self):
        if self.held:
            self.action.emit(self.held)
            self.repeat.start(REPEAT_NEXT)

    def poll(self):
        try:
            events = pygame.event.get()
        except Exception:
            return
        for e in events:
            if e.type == pygame.CONTROLLERDEVICEADDED:
                self._open(e.device_index)
            elif e.type == pygame.CONTROLLERDEVICEREMOVED:
                self.pads.pop(e.instance_id, None)
                self.connected.emit(bool(self.pads))
            elif e.type == pygame.CONTROLLERBUTTONDOWN:
                if e.button in self.dpad:
                    self._press(self.dpad[e.button])
                elif e.button in self.buttons:
                    self.action.emit(self.buttons[e.button])
            elif e.type == pygame.CONTROLLERBUTTONUP and e.button in self.dpad:
                if self.held == self.dpad[e.button]:
                    self._press(None)
            elif e.type == pygame.CONTROLLERAXISMOTION:
                self._axis(e.axis, e.value / 32767.0)
        if abs(self.scroll) > 0.25:
            self.action.emit(f"glide:{self.scroll:.2f}")

    def _axis(self, axis, value):
        if axis in (pygame.CONTROLLER_AXIS_LEFTX, pygame.CONTROLLER_AXIS_LEFTY):
            pad = next(iter(self.pads.values()), None)
            if pad is None:
                return
            x = pad.get_axis(pygame.CONTROLLER_AXIS_LEFTX) / 32767.0
            y = pad.get_axis(pygame.CONTROLLER_AXIS_LEFTY) / 32767.0
            if max(abs(x), abs(y)) < DEADZONE:
                direction = None
            elif abs(x) > abs(y):
                direction = "right" if x > 0 else "left"
            else:
                direction = "down" if y > 0 else "up"
            if direction != self.held and (direction or self.held in ("up", "down", "left", "right")):
                self._press(direction)
        elif axis == pygame.CONTROLLER_AXIS_RIGHTX:
            self.scroll = value if abs(value) > 0.25 else 0.0
        elif axis in (pygame.CONTROLLER_AXIS_TRIGGERLEFT, pygame.CONTROLLER_AXIS_TRIGGERRIGHT):
            key = "lt" if axis == pygame.CONTROLLER_AXIS_TRIGGERLEFT else "rt"
            down = value > 0.5
            if down and not self.trigger_down[key]:
                self.action.emit("page_left" if key == "lt" else "page_right")
            self.trigger_down[key] = down
