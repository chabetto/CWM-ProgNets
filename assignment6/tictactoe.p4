#include <core.p4>
#include <v1model.p4>

/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/* define 3 states each square can be in */
const bit<16> TTT_ETYPE     = 0x1234;
const bit<8>  TTT_VER       = 0x01;   // v0.1
const bit<8>  TTT_CROSS     = 0x78;   // 'x' player
const bit<8>  TTT_BLANK     = 0x2d;   // '-' blank
const bit<8>  TTT_NAUGHT    = 0x6f;   // 'o' switch
/* initialisation (who starts) */
const bit<16>  TTT_STARTSW   = 0x7377;   // switch starts game
const bit<16>  TTT_STARTPL   = 0x706c;   // player starts game
/* current state of the game */
const bit<16>  TTT_SWWIN     = 0x7376;   // switch wins
const bit<16>  TTT_PLWIN     = 0x7076;   // player wins
const bit<16>  TTT_DRAW      = 0x6472;   // drawn game
const bit<16>  TTT_PLAY      = 0x7067;   // currently still in play
/* square to put on */
const bit<16>  TTT_TL   = 0x746c;   // top left
const bit<16>  TTT_TM   = 0x746d;   // top middle
const bit<16>  TTT_TR   = 0x7472;   // top right
const bit<16>  TTT_ML   = 0x6d6c;   // middle left
const bit<16>  TTT_MM   = 0x6d6d;   // middle middle
const bit<16>  TTT_MR   = 0x6d72;   // middle right
const bit<16>  TTT_BL   = 0x626c;   // bottom left
const bit<16>  TTT_BM   = 0x626d;   // bottom middle
const bit<16>  TTT_BR   = 0x6272;   // bottom right

/*
 * ttt_t header
   entries based on above protocol header definition.
 */
 
header ttt_t {
/* version */
    bit<8> ver;
/*  state that is entered by user which can be
    switch starts
    player starts
    player entering which square
*/
    bit<16> state;
/* table */
    bit<8> tl;
    bit<8> tm;
    bit<8> tr;
    bit<8> ml;
    bit<8> mm;
    bit<8> mr;
    bit<8> bl;
    bit<8> bm;
    bit<8> br;
/* output - win/draw or still playing */
    bit<16> status;
}

struct headers {
    ethernet_t   ethernet;
    ttt_t     ttt;
}

/*
 * All metadata, globally used in the program, also  needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */

struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TTT_ETYPE : check_ttt;
            default      : accept;
        }
    }

    state check_ttt {
        transition select(packet.lookahead<ttt_t>().ver) {
            TTT_VER : parse_ttt;
            default    : accept;
        }
    }

    state parse_ttt {
        packet.extract(hdr.ttt);
        transition accept;
    }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    register<bit<8>>(72) boardReg;

    action save_board() {
        boardReg.write((bit<32>)0, hdr.ttt.tl);
        boardReg.write((bit<32>)1, hdr.ttt.tm);
        boardReg.write((bit<32>)2, hdr.ttt.tr);
        boardReg.write((bit<32>)3, hdr.ttt.ml);
        boardReg.write((bit<32>)4, hdr.ttt.mm);
        boardReg.write((bit<32>)5, hdr.ttt.mr);
        boardReg.write((bit<32>)6, hdr.ttt.bl);
        boardReg.write((bit<32>)7, hdr.ttt.bm);
        boardReg.write((bit<32>)8, hdr.ttt.br);
    }

    action load_board() {
        boardReg.read(hdr.ttt.tl, (bit<32>)0);
        boardReg.read(hdr.ttt.tm, (bit<32>)1);
        boardReg.read(hdr.ttt.tr, (bit<32>)2);
        boardReg.read(hdr.ttt.ml, (bit<32>)3);
        boardReg.read(hdr.ttt.mm, (bit<32>)4);
        boardReg.read(hdr.ttt.mr, (bit<32>)5);
        boardReg.read(hdr.ttt.bl, (bit<32>)6);
        boardReg.read(hdr.ttt.bm, (bit<32>)7);
        boardReg.read(hdr.ttt.br, (bit<32>)8);
    }

    action send_back() {
         bit<48> tmp;
         tmp = hdr.ethernet.dstAddr;
         hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
         hdr.ethernet.srcAddr = tmp;
         standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    action check_win(bit<8> sq) {
        bit<2> win = 0;
        if (hdr.ttt.mm == sq) {
            if ((hdr.ttt.ml == sq) && (hdr.ttt.mr == sq)) {
                win = 1;
            }
            if ((hdr.ttt.tm == sq) && (hdr.ttt.bm == sq)) {
                win = 1;
            }
            if ((hdr.ttt.tl == sq) && (hdr.ttt.br == sq)) {
                win = 1;
            }
            if ((hdr.ttt.tr == sq) && (hdr.ttt.bl == sq)) {
                win = 1;
            }
        }
        if (hdr.ttt.tl == sq) {
            if ((hdr.ttt.tm == sq) && (hdr.ttt.tr == sq)) {
                win = 1;
            }
            if ((hdr.ttt.ml == sq) && (hdr.ttt.bl == sq)) {
                win = 1;
            }
        }
        if (hdr.ttt.br == sq) {
            if ((hdr.ttt.bm == sq) && (hdr.ttt.bl == sq)) {
                win = 1;
            }
            if ((hdr.ttt.tr == sq) && (hdr.ttt.mr == sq)) {
                win = 1;
            }
        }
        if ((hdr.ttt.tl != TTT_BLANK) && (hdr.ttt.tm != TTT_BLANK) && (hdr.ttt.tr != TTT_BLANK) &&
        (hdr.ttt.ml != TTT_BLANK) && (hdr.ttt.mm != TTT_BLANK) && (hdr.ttt.mr != TTT_BLANK) &&
        (hdr.ttt.bl != TTT_BLANK) && (hdr.ttt.bm != TTT_BLANK) && (hdr.ttt.br != TTT_BLANK)) {
            win = 2;
        }
        if ((sq == TTT_CROSS) && (win == 1)) {
            hdr.ttt.status = TTT_PLWIN;
        } else if ((sq == TTT_NAUGHT) && (win == 1)) {
            hdr.ttt.status = TTT_SWWIN;
        } else if (win == 2) {
            hdr.ttt.status = TTT_DRAW;
        }
    }

    action clearBoard() {
        hdr.ttt.bl = TTT_BLANK;
        hdr.ttt.bm = TTT_BLANK;
        hdr.ttt.br = TTT_BLANK;
        hdr.ttt.ml = TTT_BLANK;
        hdr.ttt.mm = TTT_BLANK;
        hdr.ttt.mr = TTT_BLANK;
        hdr.ttt.tl = TTT_BLANK;
        hdr.ttt.tm = TTT_BLANK;
        hdr.ttt.tr = TTT_BLANK;
        hdr.ttt.status = TTT_PLAY;
    }

    action player_place() {
        bit<16> sq = hdr.ttt.state;
        if (sq == TTT_TL) {
            if (hdr.ttt.tl == TTT_BLANK) {
                hdr.ttt.tl = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_TM) {
            if (hdr.ttt.tm == TTT_BLANK) {
                hdr.ttt.tm = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_TR) {
            if (hdr.ttt.tr == TTT_BLANK) {
                hdr.ttt.tr = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_ML) {
            if (hdr.ttt.ml == TTT_BLANK) {
                hdr.ttt.ml = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_MM) {
            if (hdr.ttt.mm == TTT_BLANK) {
                hdr.ttt.mm = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_MR) {
            if (hdr.ttt.mr == TTT_BLANK) {
                hdr.ttt.mr = TTT_CROSS;
            } else {
                send_back();
            }
        }  else if (sq == TTT_BL) {
            if (hdr.ttt.bl == TTT_BLANK) {
                hdr.ttt.bl = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_BM) {
            if (hdr.ttt.bm == TTT_BLANK) {
                hdr.ttt.bm = TTT_CROSS;
            } else {
                send_back();
            }
        } else if (sq == TTT_BR) {
            if (hdr.ttt.br == TTT_BLANK) {
                hdr.ttt.br = TTT_CROSS;
            } else {
                send_back();
            }
        }
    }

    action next_place() {
        if (hdr.ttt.tl == TTT_BLANK) {
            hdr.ttt.tl = TTT_NAUGHT;
        } else if (hdr.ttt.tm == TTT_BLANK) {
            hdr.ttt.tm = TTT_NAUGHT;
        } else if (hdr.ttt.tr == TTT_BLANK) {
            hdr.ttt.tr = TTT_NAUGHT;
        } else if (hdr.ttt.ml == TTT_BLANK) {
            hdr.ttt.ml = TTT_NAUGHT;
        } else if (hdr.ttt.mm == TTT_BLANK) {
            hdr.ttt.mm = TTT_NAUGHT;
        } else if (hdr.ttt.mr == TTT_BLANK) {
            hdr.ttt.mr = TTT_NAUGHT;
        } else if (hdr.ttt.bl == TTT_BLANK) {
            hdr.ttt.bl = TTT_NAUGHT;
        } else if (hdr.ttt.bm == TTT_BLANK) {
            hdr.ttt.bm = TTT_NAUGHT;
        } else if (hdr.ttt.br == TTT_BLANK) {
            hdr.ttt.br = TTT_NAUGHT;
        }
    }

    /*action check_for_state(bit<8> sq) {
        if ((hdr.ttt.mm == sq) && (hdr.ttt.tm == sq) && (hdr.ttt.bm == TTT_BLANK)) {
            hdr.ttt.bm = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        }  else if ((hdr.ttt.mm == sq) && (hdr.ttt.bm == sq) && (hdr.ttt.tm == TTT_BLANK)) {
            hdr.ttt.tm = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.ml == sq) && (hdr.ttt.mr == TTT_BLANK)) {
            hdr.ttt.mr = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.mr == sq) && (hdr.ttt.ml == TTT_BLANK)) {
            hdr.ttt.ml = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.tl == sq) && (hdr.ttt.br == TTT_BLANK)) {
            hdr.ttt.br = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.br == sq) && (hdr.ttt.tl == TTT_BLANK)) {
            hdr.ttt.tl = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.bl == sq) && (hdr.ttt.tr == TTT_BLANK)) {
            hdr.ttt.tr = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.mm == sq) && (hdr.ttt.tr == sq) && (hdr.ttt.bl == TTT_BLANK)) {
            hdr.ttt.bl = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.tl == sq) && (hdr.ttt.tr == sq) && (hdr.ttt.tm == TTT_BLANK)) {
            hdr.ttt.tm = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.tl == sq) && (hdr.ttt.tm == sq) && (hdr.ttt.tr == TTT_BLANK)) {
            hdr.ttt.tr = TTT_NAUGHT;
            swPl.write((bit<32>)0, 1);
        } else if ((hdr.ttt.tl == sq) && (hdr.ttt.ml == sq) && (hdr.ttt.bl == TTT_BLANK)) {
            hdr.ttt.bl = TTT_NAUGHT;
        } else if ((hdr.ttt.tl == sq) && (hdr.ttt.bl == sq) && (hdr.ttt.ml == TTT_BLANK)) {
            hdr.ttt.bm = TTT_NAUGHT;
        } else if ((hdr.ttt.br == sq) &&(hdr.ttt.tr == sq) && (hdr.ttt.mr == TTT_BLANK)) {
            hdr.ttt.mr = TTT_NAUGHT;
        } else if ((hdr.ttt.br == sq) &&(hdr.ttt.mr == sq) && (hdr.ttt.tr == TTT_BLANK)) {
            hdr.ttt.tr = TTT_NAUGHT;
        } else if ((hdr.ttt.br == sq) &&(hdr.ttt.bm == sq) && (hdr.ttt.bl == TTT_BLANK)) {
            hdr.ttt.bl = TTT_NAUGHT;
        } else if ((hdr.ttt.br == sq) &&(hdr.ttt.bl == sq) && (hdr.ttt.bm == TTT_BLANK)) {
            hdr.ttt.bm = TTT_NAUGHT;
        } 
    }*/
    

    action sw_place() {
        if (hdr.ttt.mm == TTT_BLANK) {
            hdr.ttt.mm = TTT_NAUGHT; // if middle is not taken take the middle
        } else {
            if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.tm == TTT_NAUGHT) && (hdr.ttt.bm == TTT_BLANK)) {
                hdr.ttt.bm = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.bm == TTT_NAUGHT) && (hdr.ttt.tm == TTT_BLANK)) {
                hdr.ttt.tm = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.ml == TTT_NAUGHT) && (hdr.ttt.mr == TTT_BLANK)) {
                hdr.ttt.mr = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.mr == TTT_NAUGHT) && (hdr.ttt.ml == TTT_BLANK)) {
                hdr.ttt.ml = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.tl == TTT_NAUGHT) && (hdr.ttt.br == TTT_BLANK)) {
                hdr.ttt.br = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.br == TTT_NAUGHT) && (hdr.ttt.tl == TTT_BLANK)) {
                hdr.ttt.tl = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.bl == TTT_NAUGHT) && (hdr.ttt.tr == TTT_BLANK)) {
                hdr.ttt.tr = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_NAUGHT) && (hdr.ttt.tr == TTT_NAUGHT) && (hdr.ttt.bl == TTT_BLANK)) {
                hdr.ttt.bl = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.tm == TTT_CROSS) && (hdr.ttt.bm == TTT_BLANK)) {
                hdr.ttt.bm = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.bm == TTT_CROSS) && (hdr.ttt.tm == TTT_BLANK)) {
                hdr.ttt.tm = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.ml == TTT_CROSS) && (hdr.ttt.mr == TTT_BLANK)) {
                hdr.ttt.mr = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.mr == TTT_CROSS) && (hdr.ttt.ml == TTT_BLANK)) {
                hdr.ttt.ml = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.tl == TTT_CROSS) && (hdr.ttt.br == TTT_BLANK)) {
                hdr.ttt.br = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.br == TTT_CROSS) && (hdr.ttt.tl == TTT_BLANK)) {
                hdr.ttt.tl = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.bl == TTT_CROSS) && (hdr.ttt.tr == TTT_BLANK)) {
                hdr.ttt.tr = TTT_NAUGHT;
            } else if ((hdr.ttt.mm == TTT_CROSS) && (hdr.ttt.tr == TTT_CROSS) && (hdr.ttt.bl == TTT_BLANK)) {
                hdr.ttt.bl = TTT_NAUGHT;
            } else {
                next_place();
            }
        }
    }

    action operation_play() {
        load_board();
        player_place();
        check_win(TTT_CROSS);
        if (hdr.ttt.status == TTT_PLAY){
            sw_place();
            check_win(TTT_NAUGHT);
        }
        save_board();
        send_back();
    }

    action operation_startSw() {
        /* clear board and input first move */
        clearBoard();
        sw_place();
        save_board();
        send_back();
    }

    action operation_startPl() {
        /* clear board and send back so player can input their move */
        clearBoard();
        save_board();
        send_back();
    }

    action drop_packet() {
        mark_to_drop(standard_metadata);
    }

    table currentState {
        key = {
            hdr.ttt.state        : exact;
        }
        actions = {
            operation_play;
            operation_startSw;
            operation_startPl;
            drop_packet;
        }
        const default_action = drop_packet();
        const entries = {
            TTT_TL       : operation_play();
            TTT_TM       : operation_play();
            TTT_TR       : operation_play();
            TTT_ML       : operation_play();
            TTT_MM       : operation_play();
            TTT_MR       : operation_play();
            TTT_BL       : operation_play();
            TTT_BM       : operation_play();
            TTT_BR       : operation_play();
            TTT_STARTSW  : operation_startSw();
            TTT_STARTPL  : operation_startPl();
        }
    }

    apply {
        if (hdr.ttt.isValid()) {
            currentState.apply();
        } else {
            drop_packet();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ttt);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
