"""AutoTyper - paste text, press F8, it types into whatever window is focused.

Speed slider: 0 = instant, higher = delay per character (seconds).
F9 = stop mid-typing. Esc in this window = quit.
"""
import random
import threading
import time
import tkinter as tk
from tkinter import ttk

import keyboard

stop_flag = threading.Event()


def do_type():
    stop_flag.clear()
    text = text_box.get("1.0", "end-1c")
    if not text:
        return
    delay = speed.get() / 1000.0  # ms -> s
    status.set("Typing... (F9 stops)")
    if delay == 0:
        keyboard.write(text)
    else:
        for ch in text:
            if stop_flag.is_set():
                status.set("Stopped.")
                return
            keyboard.write(ch)
            # +/- 20ms random jitter so keystrokes don't look robotic
            time.sleep(max(0.0, delay + random.uniform(-0.02, 0.02)))
    status.set("Done. F8 to type again.")


def start_typing():
    threading.Thread(target=do_type, daemon=True).start()


def stop_typing():
    stop_flag.set()


root = tk.Tk()
root.title("AutoTyper - F8 type, F9 stop")
root.geometry("520x420")
root.attributes("-topmost", True)

tk.Label(root, text="Text to type:").pack(anchor="w", padx=8, pady=(8, 0))
text_box = tk.Text(root, height=12, wrap="word")
text_box.pack(fill="both", expand=True, padx=8, pady=4)

frame = tk.Frame(root)
frame.pack(fill="x", padx=8)
tk.Label(frame, text="Delay per char (ms):").pack(side="left")
speed = tk.IntVar(value=100)
ttk.Scale(frame, from_=80, to=200, variable=speed, orient="horizontal").pack(
    side="left", fill="x", expand=True, padx=8)
speed_label = tk.Label(frame, width=4)
speed_label.pack(side="left")
speed.trace_add("write", lambda *_: speed_label.config(text=str(speed.get())))
speed_label.config(text="100")

btns = tk.Frame(root)
btns.pack(fill="x", padx=8, pady=6)
tk.Button(btns, text="Type (F8)", command=start_typing).pack(side="left", padx=4)
tk.Button(btns, text="Stop (F9)", command=stop_typing).pack(side="left", padx=4)

status = tk.StringVar(value="Paste text, focus target window, press F8.")
tk.Label(root, textvariable=status, fg="blue").pack(anchor="w", padx=8, pady=(0, 8))

keyboard.add_hotkey("f8", start_typing)
keyboard.add_hotkey("f9", stop_typing)
root.bind("<Escape>", lambda e: root.destroy())

root.mainloop()
