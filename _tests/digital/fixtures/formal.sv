// SPDX-FileCopyrightText: 2026 Johannes Kepler University
// SPDX-License-Identifier: Apache-2.0

module formal_top(input logic a);
    always_comb assert (a == a);
endmodule
