#!/usr/bin/python3

from evdev import ecodes, InputDevice
from time import time
from select import select
import os
import sys
import evdev

sys_touchscreen_path = os.readlink("/etc/dev/touchscreen")
sys_touchscreen_driver = os.path.dirname(sys_touchscreen_path)
sys_touchscreen_node = os.path.basename(sys_touchscreen_path)

def enable_touchscreen():
  try:
    with open(sys_touchscreen_driver+"/bind","w") as f:
      f.write(sys_touchscreen_node+"\n")
  except: pass

def disable_touchscreen():
  try:
    with open(sys_touchscreen_driver+"/unbind","w") as f:
      f.write(sys_touchscreen_node+"\n")
  except: pass

def get_screen_brightness():
  with open("/etc/dev/backlight/brightness") as f:
    return int(f.read())

def set_screen_brightness(brightness):
  with open("/etc/dev/backlight/brightness", "w") as f:
    f.write(str(brightness) + "\n")

def readall(path):
  with open(path, "r") as f:
    return f.read()

def on():
  enable_touchscreen()

def off():
  disable_touchscreen()

last_brightness = get_screen_brightness() or readall("/etc/dev/default-brightness")

def main(args):
  global last_brightness

  dev = InputDevice("/etc/dev/power-key")

  while True:
    # Block for a 1s or until there are events to be read.
    r, _, _ = select([dev], [], [], 1)

    brightness = get_screen_brightness()
    if brightness:
      on()
    else:
      off()

    if not r:
      continue

    for event in dev.read():
      if event.type == ecodes.EV_KEY and event.value == 1 and event.code == ecodes.KEY_POWER:
        if brightness:
          last_brightness = get_screen_brightness() or last_brightness
          set_screen_brightness(0)
          off()
        else:
          on()
          set_screen_brightness(last_brightness)


if __name__ == "__main__":
  sys.exit(main(sys.argv))
