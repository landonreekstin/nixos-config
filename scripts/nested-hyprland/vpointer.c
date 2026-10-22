/* scripts/nested-hyprland/vpointer.c
 *
 * A virtual mouse that STAYS plugged in, for driving a nested Hyprland test session
 * (docs/test-vms-and-ci.md "Testing Hyprland without KVM"). A nested Hyprland has no
 * pointer of its own, so wl_seat advertises none and GTK clients never create one;
 * wlrctl adds a pointer only for the instant of each command, which they miss.
 *
 * Usage: vpointer W H  (the layout extent), then commands on stdin:
 *   move X Y   absolute position     rel DX DY   relative motion (what drags need)
 *   down / up  hold / release left   click / mclick   left / middle click
 *   sleep MS                                                              */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct zwlr_virtual_pointer_manager_v1 *mgr;
static struct wl_seat *seat;
static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t v) {
  if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
    mgr = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
  else if (!strcmp(iface, wl_seat_interface.name))
    seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
}
static void global_remove(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = { global, global_remove };
static uint32_t now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }

int main(int argc, char **argv) {
  uint32_t W = atoi(argv[1]), H = atoi(argv[2]);
  struct wl_display *dpy = wl_display_connect(NULL);
  if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
  struct wl_registry *reg = wl_display_get_registry(dpy);
  wl_registry_add_listener(reg, &rl, NULL);
  wl_display_roundtrip(dpy);
  if (!mgr) { fprintf(stderr, "no virtual pointer manager\n"); return 1; }
  struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, seat);
  wl_display_roundtrip(dpy);
  char line[256];
  while (fgets(line, sizeof line, stdin)) {
    int x, y, ms; unsigned btn = 0x110;
    if (sscanf(line, "move %d %d", &x, &y) == 2) {
      zwlr_virtual_pointer_v1_motion_absolute(p, now(), x, y, W, H);
      zwlr_virtual_pointer_v1_frame(p);
    } else if (!strncmp(line, "click", 5) || !strncmp(line, "mclick", 6)) {
      if (line[0] == 'm') btn = 0x112;
      zwlr_virtual_pointer_v1_button(p, now(), btn, 1); zwlr_virtual_pointer_v1_frame(p);
      wl_display_flush(dpy); usleep(60000);
      zwlr_virtual_pointer_v1_button(p, now(), btn, 0); zwlr_virtual_pointer_v1_frame(p);
    } else if (sscanf(line, "rel %d %d", &x, &y) == 2) {
      zwlr_virtual_pointer_v1_motion(p, now(), wl_fixed_from_int(x), wl_fixed_from_int(y));
      zwlr_virtual_pointer_v1_frame(p);
    } else if (!strncmp(line, "down", 4) || !strncmp(line, "up", 2)) {
      zwlr_virtual_pointer_v1_button(p, now(), 0x110, line[0] == 'd'); zwlr_virtual_pointer_v1_frame(p);
    } else if (sscanf(line, "sleep %d", &ms) == 1) {
      wl_display_flush(dpy); usleep(ms * 1000);
    }
    wl_display_flush(dpy);
    wl_display_dispatch_pending(dpy);
  }
  return 0;
}
