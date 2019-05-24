#!/usr/bin/env python

import sys

green = red = bold = False
pending = False
eof = False
while not eof:
    buf = sys.stdin.read(1)
    if len(buf) <= 0:
        eof = True
        break

    c1 = buf[0]
    if ord(c1) != 27:   # escape character
        if pending:
            if red:
                sys.stdout.write('\n```diff\n- ')
            elif green:
                sys.stdout.write('\n```diff\n+ ')
            if bold:
                sys.stdout.write('**')
        pending = False
        if c1 == '\n':
            if red: sys.stdout.write('\n- ')
            elif green: sys.stdout.write('\n+ ')
            elif bold: sys.stdout.write('**\n**')
            else: sys.stdout.write('\n')
        else:
            sys.stdout.write(c1)
        continue
            
    if ord(c1) == 27:    # escape character
        buf2 = sys.stdin.read(1)
        if len(buf2) <= 0:
            sys.stdout.write(c1)
            eof = True
            break

        c2 = buf2[0]
        if c2 != '[':   # control sequence introducer
            sys.stdout.write(c1+c2)
            continue

        buf3 = sys.stdin.read(1)
        if len(buf3) <= 0:
            sys.stdout.write(c1+c2)
            eof = True
            break

        c3 = buf3[0]
        n = ''

        while c3 >= '0' and c3 <= '9':
            n += c3
            buf3 = sys.stdin.read(1)
            if len(buf3) <= 0:
                sys.stdout.write(c1+c2+n)
                eof = True
                break
            c3 = buf3[0]

        if c3 != 'm':   # select graphic rendition
            # unsupported escape sequence
            sys.stdout.write(c1+c2+n+c3)
            continue

        i = int(n)
        if i == 0:      # reset
            if (green or red) and not pending:
                sys.stdout.write('\n```\n')
            elif bold and not pending:
                sys.stdout.write('**')
            green = red = bold = pending = False
        elif i == 1 and not (red or green): # bold
            bold = True
            pending = True
        elif i == 31:   # red
            if green:
                if not pending: sys.stdout.write('\n- ')
                green = False
                red = True
            elif bold:
                if not pending: sys.stdout.write('**\n- ')
                bold = False
                red = True
            else:
                red = True
                pending = True
        elif i == 32: # green
            if red:
                if not pending: sys.stdout.write('\n+ ')
                red = False
                green = True
            elif bold:
                if not pending: sys.stdout.write('**\n+ ')
                bold = False
                green = True
            else:
                green = True
                pending = True

if red or green:
    sys.stdout.write('\n```\n')
elif bold:
    sys.stdout.write('**')

                        
                    
                
                
                
                
                
