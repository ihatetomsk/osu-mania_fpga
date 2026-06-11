#!/usr/bin/env python3
import sys
import serial
import serial.tools.list_ports
from pynput import keyboard

# Специальные коды для управляющих клавиш (должны совпадать с VHDL-константами)
KEY_UP    = 0x80
KEY_DOWN  = 0x81
KEY_LEFT  = 0x82
KEY_RIGHT = 0x83
KEY_PLUS  = 0x2B   # '+'
KEY_MINUS = 0x2D   # '-'
KEY_ENTER = 0x0D

def key_to_code(key):
    if isinstance(key, keyboard.KeyCode):
        if key.char is not None:
            return ord(key.char)
    elif isinstance(key, keyboard.Key):
        mapping = {
            keyboard.Key.up:    KEY_UP,
            keyboard.Key.down:  KEY_DOWN,
            keyboard.Key.left:  KEY_LEFT,
            keyboard.Key.right: KEY_RIGHT,
            keyboard.Key.enter: KEY_ENTER,
            keyboard.Key.space: 0x20,  
        }
        if key in mapping:
            return mapping[key]
    return None

def on_press(key):
    code = key_to_code(key)
    if code is not None:
        ser.write(bytes([code, 0x01]))
        print(f"Нажато: 0x{code:02X} -> [{code:02X} 01]")
    return True

def on_release(key):
    code = key_to_code(key)
    if code is not None:
        ser.write(bytes([code, 0x00]))
        print(f"Отпущено: 0x{code:02X} -> [{code:02X} 00]")
    # Выход по Esc
    if key == keyboard.Key.esc:
        return False
    return True

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Использование: {sys.argv[0]} <порт>")
        sys.exit(1)

    port_name = sys.argv[1]
    try:
        ser = serial.Serial(
            port=port_name,
            baudrate=5000,
            bytesize=8,
            parity='E',
            stopbits=1,
            timeout=None
        )
        print(f"Порт {port_name} открыт (5000 бод, чётность Even)")
    except Exception as e:
        print(f"Ошибка открытия порта {port_name}: {e}")
        sys.exit(1)

    print("Управление: стрелки (speed_mode), ←→ (diff_mode), +/- (mode), Enter (сброс), Esc (выход)")
    listener = keyboard.Listener(on_press=on_press, on_release=on_release)
    listener.start()
    try:
        listener.join()
    except KeyboardInterrupt:
        pass
    finally:
        ser.close()
        print("Порт закрыт")