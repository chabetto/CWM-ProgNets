#!/usr/bin/env python3

import argparse
import sys
import socket
import random
import struct
import re

from scapy.all import sendp, send, srp1
from scapy.all import Packet, hexdump
from scapy.all import Ether, StrFixedLenField, XByteField, IntField
from scapy.all import bind_layers
import readline

class ttt(Packet):
    name = "ttt"
    fields_desc = [ XByteField("version", 0x01),
                    StrFixedLenField("state", "pl", length=2),
                    StrFixedLenField("tl", "-", length=1),
                    StrFixedLenField("tm", "-", length=1),
                    StrFixedLenField("tr", "-", length=1),
                    StrFixedLenField("ml", "-", length=1),
                    StrFixedLenField("mm", "-", length=1),
                    StrFixedLenField("mr", "-", length=1),
                    StrFixedLenField("bl", "-", length=1),
                    StrFixedLenField("bm", "-", length=1),
                    StrFixedLenField("br", "-", length=1),
                    StrFixedLenField("status", "pg", length=2)]

bind_layers(Ether, ttt, type=0x1234)

def main():

    s = ''
    iface = 'eth0'

    while True:
        s = input('> ')
        if s == "quit":
            break
        print(s)
        try:
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / ttt(state = s)
            pkt = pkt/' '

            pkt.show()
            resp = srp1(pkt, iface=iface, timeout=1, verbose=False)
        except Exception as error:
            print(error)


if __name__ == '__main__':
    main()
