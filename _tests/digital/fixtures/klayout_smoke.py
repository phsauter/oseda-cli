# SPDX-FileCopyrightText: 2026 Johannes Kepler University
# SPDX-License-Identifier: Apache-2.0

import pya

layout = pya.Layout()
cell = layout.create_cell("TOP")
layer = layout.layer(1, 0)
cell.shapes(layer).insert(pya.Box(0, 0, 1000, 1000))
layout.write("klayout-smoke.gds")

loaded = pya.Layout()
loaded.read("klayout-smoke.gds")
assert loaded.top_cell().name == "TOP"
print("KLAYOUT_SMOKE_OK")
