#!/usr/bin/env python3
# Holds the left button down, which wlrctl can't, on a virtual pointer of the
# compositor at $WAYLAND_DISPLAY: until it's told to stop, or that compositor
# goes. The button goes with the pointer, so this has to stay.
import os
import signal
import socket
import struct
import sys
import time

BUTTON = 0x110


def number(value):
    return struct.pack("=I", value)


def text(value):
    data = value.encode() + b"\0"
    return number(len(data)) + data + b"\0" * (-len(data) % 4)


def send(target, opcode, body=b""):
    wayland.sendall(struct.pack("=IHH", target, opcode, 8 + len(body)) + body)


# Reads what comes until callback `done` says all of it was seen.
def sync(done):
    global incoming
    send(1, 0, number(done))
    while True:
        while len(incoming) >= 8:
            target, opcode, size = struct.unpack_from("=IHH", incoming)
            if len(incoming) < size:
                break
            body, incoming = incoming[8:size], incoming[size:]
            if target == done:
                return
            if target == 2 and opcode == 0:
                length = struct.unpack_from("=I", body, 4)[0]
                globals_[body[8 : 8 + length - 1].decode()] = struct.unpack_from("=I", body)[0]
        incoming += wayland.recv(65536)


wayland = socket.socket(socket.AF_UNIX)
wayland.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))
incoming = b""
globals_ = {}

send(1, 1, number(2))
sync(3)
manager = "zwlr_virtual_pointer_manager_v1"
send(2, 0, number(globals_[manager]) + text(manager) + number(1) + number(4))
send(4, 0, number(0) + number(5))


def press(state, done):
    send(5, 2, number(int(time.monotonic() * 1000) & 0xFFFFFFFF) + number(BUTTON) + number(state))
    send(5, 4)
    sync(done)


def release(*_):
    press(0, 7)
    sys.exit()


signal.signal(signal.SIGTERM, release)
press(1, 6)
while wayland.recv(4096):
    pass
