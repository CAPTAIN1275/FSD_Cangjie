#!/usr/bin/env python3
"""voice_relay.py — FSD 语音中继（TCP 信令 + UDP 语音）"""
import socket, threading, json, struct, sys

TCP_PORT = 6808
UDP_PORT = 6807
clients = {}       # callsign -> {"addr": (ip, port), "freq": str, "tcp": socket}
lock = threading.Lock()

def handle_tcp(conn, addr):
    callsign = ""
    buf = b""
    try:
        while True:
            c = conn.recv(1)
            if not c: break
            if c == b"\n":
                if not callsign:
                    callsign = buf.decode("utf-8", errors="replace").strip()
                    if callsign:
                        with lock:
                            clients[callsign] = {"addr": None, "freq": "0", "tcp": conn}
                        print(f"[Voice] + {callsign} ({addr[0]})", flush=True)
                        conn.sendall(f"SERVER:{callsign}\n".encode())
                    buf = b""
                    continue
                msg = buf.decode("utf-8", errors="replace").strip()
                buf = b""
                if msg:
                    try:
                        j = json.loads(msg)
                        t = j.get("type", "")
                        if t == "channel":
                            f = j.get("data", "0").split(":")[0]
                            with lock:
                                if callsign in clients:
                                    clients[callsign]["freq"] = f
                        elif t == "ping":
                            conn.sendall(b'{"type":"pong"}\n')
                    except: pass
                continue
            buf += c
    except: pass
    finally:
        with lock:
            clients.pop(callsign, None)
        print(f"[Voice] - {callsign}", flush=True)
        try: conn.close()
        except: pass

def handle_udp():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", UDP_PORT))
    print(f"[Voice] UDP on {UDP_PORT}", flush=True)
    while True:
        try:
            data, addr = s.recvfrom(4096)
            if len(data) < 8: continue
            # Packet: [4B len][4B freq][payload]
            fl = struct.unpack("<I", data[:4])[0]
            fq = struct.unpack("<I", data[4:8])[0]
            total = 8 + fl
            if len(data) < total: continue
            # 查找对应的 callsign（通过 UDP 地址匹配）
            with lock:
                sender_cs = None
                for cs, cl in clients.items():
                    if cl["addr"] == addr:
                        sender_cs = cs
                        break
                if sender_cs is None:
                    # 首次收到 UDP 包，记录地址
                    for cs, cl in clients.items():
                        if cl["addr"] is None:
                            cl["addr"] = addr
                            sender_cs = cs
                            print(f"[Voice] UDP from {cs} via {addr}", flush=True)
                            break
                if sender_cs:
                    for cs, cl in clients.items():
                        if cs != sender_cs and cl["freq"] == str(fq) and cl["addr"]:
                            try: s.sendto(data[:total], cl["addr"])
                            except: pass
        except: pass

def main():
    # UDP 线程
    threading.Thread(target=handle_udp, daemon=True).start()
    # TCP 监听
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", TCP_PORT))
    s.listen(32)
    print(f"[Voice] Relay on TCP {TCP_PORT} + UDP {UDP_PORT}", flush=True)
    while True:
        try:
            c, a = s.accept()
            threading.Thread(target=handle_tcp, args=(c, a), daemon=True).start()
        except: break

if __name__ == "__main__":
    main()
