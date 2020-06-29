#!/usr/bin/python3

from evdev import ecodes, InputDevice
from time import time
from select import select
import os
import sys
import evdev

def enable_touchscreen():
  try:
    with open("/sys/bus/i2c/drivers/edt_ft5x06/bind","w") as f:
      f.write("2-0038\n")
  except: pass

def disable_touchscreen():
  try:
    with open("/sys/bus/i2c/drivers/edt_ft5x06/unbind","w") as f:
      f.write("2-0038\n")
  except: pass

def get_screen_brightness():
  with open("/sys/class/backlight/backlight-dsi/brightness") as f:
    return int(f.read())

def set_screen_brightness(brightness):
  with open("/sys/class/backlight/backlight-dsi/brightness", "w") as f:
    f.write(str(brightness) + "\n")

def on():
  enable_touchscreen()

def off():
  disable_touchscreen()

last_brightness = get_screen_brightness() or 200

def main(args):
  global last_brightness

  powerkeyname = '30370000.snvs:snvs-powerkey'

  path = [path for path in evdev.list_devices() if evdev.InputDevice(path).name == powerkeyname]
  foundpath = ''.join(path)
  dev = InputDevice(foundpath)

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
