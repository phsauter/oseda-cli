// SPDX-FileCopyrightText: 2026 Johannes Kepler University
// SPDX-License-Identifier: Apache-2.0

module simple_tb;
    logic [7:0] a;
    logic [7:0] b;
    logic [8:0] sum;

    adder dut (
        .a_i(a),
        .b_i(b),
        .sum_o(sum)
    );

    initial begin
        a = 8'd17;
        b = 8'd25;
        #1;
        if (sum != 9'd42)
            $fatal(1, "unexpected sum");
        $display("VERILATOR_SMOKE_OK");
        $finish;
    end
endmodule
