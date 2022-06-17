#!/usr/bin/env python3

import argparse
import sys
import socket
import random
import struct
import re
from scapy.all import *
from scapy.all import sendp, send, srp1
from scapy.all import Packet, hexdump
from scapy.all import Ether, StrFixedLenField, XByteField, IntField
from scapy.all import bind_layers
import readline
import time
from codecs import decode

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
        time.sleep(0.5)
        try:
            resp2 = sniff(filter = "ether dst 00:04:00:00:00:00", iface=iface,count = 2, timeout=10)
            resp = resp2[1]
            if resp:
                rttt=resp[ttt]
                if ttt:
                    cond = rttt.status.decode('ascii')
                    print('', rttt.tl.decode('ascii'),rttt.tm.decode('ascii'),rttt.tr.decode('ascii'),'\n\n',
                    rttt.ml.decode('ascii'),rttt.mm.decode('ascii'),rttt.mr.decode('ascii'),'\n\n',
                    rttt.bl.decode('ascii'),rttt.bm.decode('ascii'),rttt.br.decode('ascii'),'\n\n')
                    if (cond == "sv"):
                        print("Switch wins\n")
                    elif (cond == "pv"):
                        print("You win\n")
                    elif (cond == "dr"):
                        print("Draw\n")
                else:
                    print("cannot find ttt header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            pass


if __name__ == '__main__':
    main()
