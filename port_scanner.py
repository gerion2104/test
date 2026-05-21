#!/usr/bin/env python3
"""Simple concurrent TCP port scanner."""

import argparse
import socket
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime


def parse_ports(spec: str) -> list[int]:
    ports: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_str, end_str = part.split("-", 1)
            start, end = int(start_str), int(end_str)
            if start > end:
                start, end = end, start
            ports.update(range(start, end + 1))
        else:
            ports.add(int(part))
    invalid = [p for p in ports if not 1 <= p <= 65535]
    if invalid:
        raise ValueError(f"ports out of range (1-65535): {invalid}")
    return sorted(ports)


def resolve_host(host: str) -> str:
    try:
        return socket.gethostbyname(host)
    except socket.gaierror as exc:
        raise SystemExit(f"could not resolve host {host!r}: {exc}")


def service_name(port: int) -> str:
    try:
        return socket.getservbyport(port, "tcp")
    except OSError:
        return "unknown"


def grab_banner(sock: socket.socket) -> str:
    try:
        sock.settimeout(1.0)
        data = sock.recv(1024)
        return data.decode("utf-8", errors="replace").strip()
    except (socket.timeout, OSError):
        return ""


def scan_port(ip: str, port: int, timeout: float, banner: bool) -> tuple[int, bool, str]:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        try:
            if sock.connect_ex((ip, port)) != 0:
                return port, False, ""
            return port, True, grab_banner(sock) if banner else ""
        except OSError:
            return port, False, ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Concurrent TCP port scanner")
    parser.add_argument("host", help="target hostname or IP address")
    parser.add_argument(
        "-p",
        "--ports",
        default="1-1024",
        help="ports to scan, e.g. '22,80,443' or '1-1024' (default: 1-1024)",
    )
    parser.add_argument(
        "-t", "--timeout", type=float, default=0.5, help="connect timeout in seconds (default: 0.5)"
    )
    parser.add_argument(
        "-w", "--workers", type=int, default=100, help="number of concurrent workers (default: 100)"
    )
    parser.add_argument("-b", "--banner", action="store_true", help="attempt to grab service banners")
    args = parser.parse_args()

    try:
        ports = parse_ports(args.ports)
    except ValueError as exc:
        parser.error(str(exc))

    ip = resolve_host(args.host)
    print(f"Scanning {args.host} ({ip}) — {len(ports)} port(s)")
    print(f"Started at {datetime.now().isoformat(timespec='seconds')}")
    print("-" * 60)

    open_ports: list[tuple[int, str]] = []
    start = datetime.now()

    try:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(scan_port, ip, p, args.timeout, args.banner) for p in ports]
            for future in as_completed(futures):
                port, is_open, banner = future.result()
                if is_open:
                    name = service_name(port)
                    line = f"{port:5d}/tcp  open  {name}"
                    if banner:
                        line += f"  | {banner}"
                    print(line)
                    open_ports.append((port, banner))
    except KeyboardInterrupt:
        print("\nScan interrupted by user.", file=sys.stderr)
        return 130

    elapsed = (datetime.now() - start).total_seconds()
    print("-" * 60)
    print(f"Done: {len(open_ports)} open port(s) in {elapsed:.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
