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
  with open("/sys/class/leds/lm36922:white:backlight_cluster/brightness") as f:
    return int(f.read())

def set_screen_brightness(brightness):
  with open("/sys/class/leds/lm36922:white:backlight_cluster/brightness", "w") as f:
    f.write(str(brightness) + "\n")

def set_dram_freq(freq):
  with open("/sys/class/devfreq/devfreq0/userspace/set_freq", "w") as f:
    f.write(str(freq) + "\n")

def on():
  global last_brightness
  set_dram_freq(800000000)
  enable_touchscreen()
  set_screen_brightness(last_brightness)

def off():
  global last_brightness
  last_brightness = get_screen_brightness() or last_brightness
  set_screen_brightness(0)
  disable_touchscreen()
  set_dram_freq(25000000)

last_brightness = get_screen_brightness() or 200

def main(args):
  powerkeyname = '30370000.snvs:snvs-powerkey'

  path = [path for path in evdev.list_devices() if evdev.InputDevice(path).name == powerkeyname]
  foundpath = ''.join(path)
  dev = InputDevice(foundpath)

  with open("/sys/class/devfreq/devfreq0/governor", "w+") as f:
    f.write("userspace\n")

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
          off()
        else:
          on()


if __name__ == "__main__":
  sys.exit(main(sys.argv))
