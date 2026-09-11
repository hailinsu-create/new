#!/usr/bin/env python3
"""Bind ParamMouthOpenY to mouth_open opacity on the Cubism-exported moc3.

Cubism FREE exported 7 quads and v5 extra tables, but no parameter keys.
py-moc3.to_file() drops those tables and zeros canvas, so Core fails.
This script keeps the original bytes and only:

  * grows mouth_open to two opacity keyforms (0 / 1)
  * adds one binding band + keys [0, 1] for ParamMouthOpenY
  * inserts 64-byte section blocks before the UV table

Do not run finish-moxi-runtime.py. That rewrites the whole file.
"""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path("/workspace")
SRC = ROOT / "characters/moxi/cubism/moxi.cubism-export.moc3"
DST = ROOT / "public/models/moxi/moxi.moc3"

ALIGN = 64
SOT_OFF = 64
SOT_COUNT = 160
COUNT_OFF = 1984

COUNT_ART_MESH_KEYFORMS = 9
COUNT_KEYFORM_BINDING_INDICES = 11
COUNT_KEYFORM_BINDING_BANDS = 12
COUNT_KEYFORM_BINDINGS = 13
COUNT_KEYS = 14

MOUTH_MESH = 2  # mouth_open
MOUTH_PARAM = 18  # ParamMouthOpenY

# SOT slots (count=0, canvas=1, layout starts at 2). See moc3._core.SECTION_LAYOUT.
SLOT_MESH_BAND = 34
SLOT_MESH_KF_BEGIN = 35
SLOT_MESH_KF_COUNTS = 36
SLOT_PARAM_BIND_BEGIN = 56
SLOT_PARAM_BIND_COUNTS = 57
SLOT_OPACITIES = 68
SLOT_DRAW_ORDERS = 69
SLOT_POS_BEGINS = 70
SLOT_BIND_INDEX = 72
SLOT_BAND_BEGIN = 73
SLOT_BAND_COUNTS = 74
SLOT_KEYS_BEGIN = 75
SLOT_KEYS_COUNTS = 76
SLOT_KEYS = 77
SLOT_UV = 78


def aligned(payload: bytes) -> bytes:
    pad = (ALIGN - (len(payload) % ALIGN)) % ALIGN
    return payload + b"\x00" * pad


def pack_i32s(values: list[int]) -> bytes:
    return aligned(struct.pack(f"<{len(values)}i", *values))


def pack_f32s(values: list[float]) -> bytes:
    return aligned(struct.pack(f"<{len(values)}f", *values))


def read_sot(data: bytes) -> list[int]:
    return list(struct.unpack_from(f"<{SOT_COUNT}I", data, SOT_OFF))


def write_sot(data: bytearray, sot: list[int]) -> None:
    struct.pack_into(f"<{SOT_COUNT}I", data, SOT_OFF, *sot)


def put_count(data: bytearray, index: int, value: int) -> None:
    struct.pack_into("<i", data, COUNT_OFF + index * 4, value)


def overlay(data: bytearray, offset: int, blob: bytes) -> None:
    data[offset : offset + len(blob)] = blob


def bind(src: Path, dst: Path) -> None:
    original = src.read_bytes()
    if original[:4] != b"MOC3" or original[4] != 5:
        raise SystemExit(f"{src} is not moc3 v5")

    sot = read_sot(original)
    uv_start = sot[SLOT_UV]
    splice_start = sot[SLOT_BIND_INDEX]
    if splice_start <= 0 or uv_start <= splice_start:
        raise SystemExit("unexpected SOT layout")

    data = bytearray(original)

    put_count(data, COUNT_ART_MESH_KEYFORMS, 8)
    put_count(data, COUNT_KEYFORM_BINDING_INDICES, 1)
    put_count(data, COUNT_KEYFORM_BINDING_BANDS, 2)
    put_count(data, COUNT_KEYFORM_BINDINGS, 1)
    put_count(data, COUNT_KEYS, 2)

    overlay(data, sot[SLOT_MESH_BAND], pack_i32s([0, 0, 1, 0, 0, 0, 0]))
    overlay(data, sot[SLOT_MESH_KF_BEGIN], pack_i32s([0, 1, 2, 4, 5, 6, 7]))
    overlay(data, sot[SLOT_MESH_KF_COUNTS], pack_i32s([1, 1, 2, 1, 1, 1, 1]))

    bind_begin = [-1] * 27
    bind_count = [0] * 27
    bind_begin[MOUTH_PARAM] = 0
    bind_count[MOUTH_PARAM] = 1
    overlay(data, sot[SLOT_PARAM_BIND_BEGIN], pack_i32s(bind_begin))
    overlay(data, sot[SLOT_PARAM_BIND_COUNTS], pack_i32s(bind_count))

    overlay(
        data,
        sot[SLOT_OPACITIES],
        pack_f32s([1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
    )
    overlay(
        data,
        sot[SLOT_DRAW_ORDERS],
        pack_f32s([600.0, 500.0, 400.0, 400.0, 310.0, 300.0, 200.0, 100.0]),
    )
    overlay(data, sot[SLOT_POS_BEGINS], pack_i32s([0, 16, 32, 32, 48, 64, 80, 96]))

    blocks = [
        (SLOT_BIND_INDEX, pack_i32s([0])),
        (SLOT_BAND_BEGIN, pack_i32s([0, 0])),
        (SLOT_BAND_COUNTS, pack_i32s([0, 1])),
        (SLOT_KEYS_BEGIN, pack_i32s([0])),
        (SLOT_KEYS_COUNTS, pack_i32s([2])),
        (SLOT_KEYS, pack_f32s([0.0, 1.0])),
    ]

    out = bytearray(data[:splice_start])
    new_sot = sot[:]
    for slot, blob in blocks:
        new_sot[slot] = len(out)
        out.extend(blob)

    delta = len(out) - uv_start
    replaced = {
        SLOT_BIND_INDEX,
        SLOT_BAND_BEGIN,
        SLOT_BAND_COUNTS,
        SLOT_KEYS_BEGIN,
        SLOT_KEYS_COUNTS,
        SLOT_KEYS,
    }
    for i, off in enumerate(sot):
        if i in replaced or off == 0:
            continue
        if off >= uv_start:
            new_sot[i] = off + delta

    out.extend(original[uv_start:])
    write_sot(out, new_sot)

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(out)
    print("wrote", dst, "bytes", len(out), "delta", len(out) - len(original))


def verify(path: Path) -> None:
    from moc3 import Moc3

    moc = Moc3.from_file(path)
    ids = list(moc.art_mesh_ids)
    if ids[MOUTH_MESH] != "mouth_open":
        raise SystemExit(f"mesh {MOUTH_MESH} is {ids[MOUTH_MESH]}, not mouth_open")
    if moc.parameter_ids[MOUTH_PARAM] != "ParamMouthOpenY":
        raise SystemExit("ParamMouthOpenY index moved")
    counts = list(moc["art_mesh.keyform_counts"])
    begins = list(moc["art_mesh.keyform_begin_indices"])
    opacities = list(moc["art_mesh_keyform.opacities"])
    if counts[MOUTH_MESH] != 2:
        raise SystemExit(f"mouth keyforms {counts}")
    start = begins[MOUTH_MESH]
    mouth_ops = opacities[start : start + 2]
    if [round(v, 3) for v in mouth_ops] != [0.0, 1.0]:
        raise SystemExit(f"mouth opacities {mouth_ops}")
    if moc["art_mesh.keyform_binding_band_indices"][MOUTH_MESH] != 1:
        raise SystemExit("mouth is not on band 1")
    if moc["parameter.keyform_binding_counts"][MOUTH_PARAM] != 1:
        raise SystemExit("ParamMouthOpenY has no binding")
    raw = path.read_bytes()
    sot = read_sot(raw)
    canvas = struct.unpack_from("<5f", raw, sot[1])
    print("verify ok")
    print("  meshes", ids)
    print("  mouth opacities", mouth_ops)
    print("  keys", list(moc["keys.values"]))
    print("  canvas@SOT1", canvas)


def main() -> None:
    source = SRC if SRC.exists() else DST
    bind(source, DST)
    verify(DST)


if __name__ == "__main__":
    main()
