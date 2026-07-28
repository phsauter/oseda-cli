// SPDX-FileCopyrightText: 2026 Johannes Kepler University
// SPDX-License-Identifier: Apache-2.0

volatile unsigned int result;

void _start(void) {
    result = 42u;
    for (;;)
        ;
}
