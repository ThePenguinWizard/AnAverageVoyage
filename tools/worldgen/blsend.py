"""Send Python code to a live Blender session running the Blender MCP add-on.

    python blsend.py <port> <file-with-code>      (or pipe code on stdin with "-")
Assign a dict to `result` in the code to get data back.
"""
import json
import socket
import sys


def send(port, code, timeout=600.0):
    req = json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0"
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)
        s.connect(("127.0.0.1", port))
        s.sendall(req.encode("utf-8"))
        buf = bytearray()
        while b"\0" not in buf:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf.extend(chunk)
    return json.loads(buf.partition(b"\0")[0].decode("utf-8"))


if __name__ == "__main__":
    port = int(sys.argv[1])
    code = sys.stdin.read() if sys.argv[2] == "-" else open(sys.argv[2], encoding="utf-8").read()
    print(json.dumps(send(port, code), indent=1)[:6000])
