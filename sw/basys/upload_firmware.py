#!/usr/bin/env python3
import sys
import time
import os
import argparse
import serial

def upload_and_run(port='/dev/ttyUSB1', baud=19200, bin_path=None):
    if not bin_path or not os.path.exists(bin_path):
        print(f"[!] Error: binary file not found at {bin_path}")
        sys.exit(1)

    file_size = os.path.getsize(bin_path)
    with open(bin_path, 'rb') as f:
        bin_data = f.read()

    print(f"[*] Connecting to {port} @ {baud} baud...")
    try:
        ser = serial.Serial(port, baud, timeout=0.5)
    except Exception as e:
        print(f"[!] Error opening serial port: {e}")
        sys.exit(1)

    with ser:
        ser.reset_input_buffer()
        print("[*] Contacting bootloader...")
        ser.write(b'\r\n')
        time.sleep(0.1)

        print("[*] Sending 'u' command (Upload via UART)...")
        ser.write(b'u')
        time.sleep(0.3)

        resp = ser.read(ser.in_waiting).decode('latin-1', errors='replace')
        if resp.strip():
            print(f"[BOOTLOADER]:\n{resp.strip()}")

        print(f"[*] Streaming {file_size} bytes of executable...")
        chunk_size = 256
        for i in range(0, file_size, chunk_size):
            ser.write(bin_data[i:i+chunk_size])
            sys.stdout.write(f"\r[*] Progress: {min(i+chunk_size, file_size)}/{file_size} bytes ({min(i+chunk_size, file_size)*100//file_size}%)")
            sys.stdout.flush()
            time.sleep(0.01)

        print("\n[*] Upload complete. Waiting for verification...")
        time.sleep(0.5)
        resp = ser.read(ser.in_waiting).decode('latin-1', errors='replace')
        if resp.strip():
            print(f"[BOOTLOADER]:\n{resp.strip()}")

        print("[*] Sending 'e' command (Execute)...")
        ser.write(b'e')
        time.sleep(0.2)

        print("\n=== APPLICATION STARTED (Press Ctrl+C to exit) ===")
        try:
            while True:
                if ser.in_waiting > 0:
                    chunk = ser.read(ser.in_waiting).decode('latin-1', errors='replace')
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
                time.sleep(0.02)
        except KeyboardInterrupt:
            print("\n[*] Exiting terminal monitor.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload executable to NEORV32 bootloader on Basys 3.")
    parser.add_argument("binary", help="Path to executable .bin file")
    parser.add_argument("--port", "-p", default="/dev/ttyUSB1", help="Serial port (default: /dev/ttyUSB1)")
    parser.add_argument("--baud", "-b", type=int, default=19200, help="Baud rate (default: 19200)")
    args = parser.parse_args()

    upload_and_run(port=args.port, baud=args.baud, bin_path=args.binary)
