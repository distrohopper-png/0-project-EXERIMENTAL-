#!/usr/bin/env python3
"""Transparent matrix rain — raw ANSI, no ncurses, inherits terminal opacity."""

import os, sys, time, random, signal, shutil
from pathlib import Path

def _load_color():
    try:
        h = (Path.home() / ".config/cmatrix/color").read_text().strip().lstrip('#')
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    except Exception:
        return (0, 220, 60)

CHARS = list('ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ012345789:・."=*+-<>¦|╌')

def _fg(r, g, b): return f'\x1b[38;2;{r};{g};{b}m'
def _at(row, col): return f'\x1b[{row};{col}H'

class _Stream:
    def __init__(self, col, rows, color):
        self.col  = col
        self.rows = rows
        self.clr  = color
        self._reset()

    def _reset(self):
        self.head   = random.randint(-self.rows, 0)
        self.length = random.randint(self.rows // 4, self.rows)
        self.speed  = random.choice([1, 1, 1, 2])
        self.chars  = [random.choice(CHARS) for _ in range(self.rows + 20)]

    def tick(self, frame):
        if frame % self.speed:
            return []
        self.head += 1
        if self.head - self.length > self.rows + 5:
            self._reset()
        r, g, b = self.clr
        out = []
        top = max(0, self.head - self.length)
        for i in range(top, min(self.rows, self.head + 1)):
            frac = (self.head - i) / max(self.length, 1)
            c = _at(i + 1, self.col + 1)
            if i == self.head:
                out.append(f'{c}\x1b[1m\x1b[37m{random.choice(CHARS)}\x1b[0m')
            elif frac < 0.3:
                out.append(f'{c}{_fg(r,g,b)}\x1b[1m{self.chars[i]}\x1b[0m')
            else:
                out.append(f'{c}{_fg(r//3,g//3,b//3)}{self.chars[i]}\x1b[0m')
        erase = self.head - self.length
        if 0 <= erase < self.rows:
            out.append(f'{_at(erase + 1, self.col + 1)} ')
        return out

def main():
    color = _load_color()

    def _quit(*_):
        sys.stdout.write('\x1b[?25h\x1b[0m\x1b[2J\x1b[H')
        sys.stdout.flush()
        sys.exit(0)

    signal.signal(signal.SIGINT,  _quit)
    signal.signal(signal.SIGTERM, _quit)

    sys.stdout.write('\x1b[?25l\x1b[2J')
    sys.stdout.flush()

    cols, rows = shutil.get_terminal_size()
    streams = [_Stream(c, rows, color) for c in range(cols)]

    frame = 0
    try:
        while True:
            # Rebuild on resize
            new_cols, new_rows = shutil.get_terminal_size()
            if new_cols != cols or new_rows != rows:
                cols, rows = new_cols, new_rows
                streams = [_Stream(c, rows, color) for c in range(cols)]
                sys.stdout.write('\x1b[2J')

            buf = []
            for s in streams:
                buf.extend(s.tick(frame))
            if buf:
                sys.stdout.write(''.join(buf))
                sys.stdout.flush()
            frame += 1
            time.sleep(0.05)
    except Exception:
        pass
    finally:
        _quit()

if __name__ == '__main__':
    main()
