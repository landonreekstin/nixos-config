"""F-117 (Briefing Room) — start the app."""

import sys

from PyQt6.QtWidgets import QApplication

from briefing import theme
from briefing.ui import MainWindow


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("F-117")
    app.setDesktopFileName("briefing-room")
    theme.load_fonts()
    window = MainWindow()
    if "--screenshot" in sys.argv:
        window.booted = "--boot" not in sys.argv  # skip the start-up screen in tests unless asked
        window.show()
    else:
        from briefing.panel import rules_before_opening

        rules_before_opening()  # Hyprland: each window opens in its place, invisible, then fades in
        window.showMaximized()  # fill the screen
    if "--screenshot" in sys.argv:
        # used during development to check the look without a screen
        from PyQt6.QtCore import QTimer

        out = sys.argv[sys.argv.index("--screenshot") + 1]  # [--tab N] [--summary] [--category ID] [--wait S]
        summary = "--summary" in sys.argv
        tab = int(sys.argv[sys.argv.index("--tab") + 1]) if "--tab" in sys.argv else 0
        wait = int(sys.argv[sys.argv.index("--wait") + 1]) if "--wait" in sys.argv else 25
        category = sys.argv[sys.argv.index("--category") + 1] if "--category" in sys.argv else None
        window.set_page(tab)
        if summary:
            window.set_mode("brief")
        if category:
            window.open_category(category)
        if "--prefs" in sys.argv:
            window.open_prefs()

        def snap():
            window.grab().save(out)
            app.quit()

        QTimer.singleShot(wait * 1000, snap)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
