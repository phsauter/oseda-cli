// SPDX-FileCopyrightText: 2026 Johannes Kepler University
// SPDX-License-Identifier: Apache-2.0

module top(input a, input b, output y);
    wire not_both_high;
    nand (not_both_high, a, b);
    not (y, not_both_high);
endmodule
