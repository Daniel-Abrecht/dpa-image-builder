#!/usr/bin/env python3

import os, fcntl, array, math
from evdev import InputDevice, categorize, ecodes

VT_GETSTATE = 0x5603
VT_ACTIVATE = 0x5606

dev = InputDevice('/dev/input/by-path/platform-gpio-keys-event')
dev.grab()

tty0 = os.open("/dev/tty0", os.O_RDONLY)

def nextvt(forward=False):
  buf = array.array('H',[0,0,0])
  fcntl.ioctl(tty0, VT_GETSTATE, buf, True)
  active, signal, state = buf.tolist()
  if state <= 0 or active < 0 or (1<<active) > state:
    return
  i = active
  first_pass = True
  while first_pass or i != active:
    first_pass = False
    i += 1 if forward else -1
    if state & (1 << i):
      try:
        fcntl.ioctl(tty0, VT_ACTIVATE, i)
        break
      except: pass
    if forward and (1 << i) > state:
      i = 0
    if not forward and i <= 0:
      i = math.ceil(math.log2(state))


for event in dev.read_loop():
  if event.type == ecodes.EV_KEY:
    key = categorize(event)
    if key.keystate == key.key_down:
      if key.keycode == 'KEY_VOLUMEUP':
        nextvt(True)
      if key.keycode == 'KEY_VOLUMEDOWN':
        nextvt(False)
