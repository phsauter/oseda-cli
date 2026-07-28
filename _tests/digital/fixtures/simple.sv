// SPDX-FileCopyrightText: 2026 Johannes Kepler University
// SPDX-License-Identifier: Apache-2.0

module adder (
    input  logic [7:0] a_i,
    input  logic [7:0] b_i,
    output logic [8:0] sum_o
);
    assign sum_o = a_i + b_i;
endmodule
