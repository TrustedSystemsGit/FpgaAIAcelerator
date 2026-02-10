// Copyright (c) 2026 Trusted Systems. MIT License. See LICENSE for details.

`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Simple UART (RS232) Module for ML605 - 9600 baud, 8N1
//──────────────────────────────────────────────────────────────────────────────
//
//  Features:
//  - TX for alert_out (e.g. send 'A' on alert)
//  - RX for label_in (e.g. receive labels from PC)
//  - Baud rate: 9600 (adjustable)
//  - Format: 8 data bits, no parity, 1 stop bit
//  - Clock: 125 MHz (oversampling x16)
//  - FIFO for TX/RX (size 16 for demo)
//
//  Integration with NIDS: 
//  - TX: send alert byte when alert_out changes
//  - RX: receive label byte → label_in
//
//  Pinout for ML605 RS232 (USB-UART):
//  - TX: GPIO (e.g. P4)
//  - RX: GPIO (e.g. P5)
//
//──────────────────────────────────────────────────────────────────────────────

module uart_rs232 #(
    parameter CLK_FREQ    = 125_000_000,  // 125 MHz
    parameter BAUD_RATE   = 9600,
    parameter FIFO_SIZE   = 16,           // Power of 2
    parameter OVERSAMPLE  = 16            // Oversampling for RX
)(
    input  clk,
    input  rst,

    // ── TX interface ────────────────────────────────────────────────────────
    input  [7:0] tx_data,                 // Byte to send
    input        tx_valid,                // Pulse to send
    output		  tx_ready,                // FIFO not full

    // ── RX interface ────────────────────────────────────────────────────────
    output reg [7:0] rx_data,             // Received byte
    output reg       rx_valid,            // Pulse on new byte
    input            rx_ready,            // Acknowledge (optional)

    // ── Physical pins ───────────────────────────────────────────────────────
    output reg tx_pin,                    // RS232 TX pin
    input      rx_pin                     // RS232 RX pin
);

//──────────────────────────────────────────────────────────────────────────────
//  Calculated constants
//──────────────────────────────────────────────────────────────────────────────

localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;  // ~13020 for 9600 at 125MHz
localparam OVERSAMPLE_DIV = BAUD_DIV / OVERSAMPLE;  // ~813

//──────────────────────────────────────────────────────────────────────────────
//  TX FIFO
//──────────────────────────────────────────────────────────────────────────────

reg [7:0] tx_fifo [0:FIFO_SIZE-1];
reg [$clog2(FIFO_SIZE):0] tx_wr_ptr = 0;
reg [$clog2(FIFO_SIZE):0] tx_rd_ptr = 0;
wire tx_empty = (tx_wr_ptr == tx_rd_ptr);
wire tx_full = ((tx_wr_ptr + 1) % FIFO_SIZE == tx_rd_ptr);
always @(posedge clk) begin
    if (rst) begin
        tx_wr_ptr <= 0;
    end else if (tx_valid && !tx_full) begin
        tx_fifo[tx_wr_ptr] <= tx_data;
        tx_wr_ptr <= (tx_wr_ptr + 1) % FIFO_SIZE;
    end
end

assign tx_ready = !tx_full;

//──────────────────────────────────────────────────────────────────────────────
//  TX state machine
//──────────────────────────────────────────────────────────────────────────────

reg [4:0] tx_state = 0;  // 0 idle, 1 start, 2-9 data bits, 10 stop
reg [7:0] tx_byte = 0;
reg [16:0] tx_cnt = 0;

always @(posedge clk) begin
    if (rst) begin
        tx_state <= 0;
        tx_pin <= 1;  // Idle high
        tx_rd_ptr <= 0;
    end else begin
        if (tx_cnt == BAUD_DIV - 1) begin
            tx_cnt <= 0;
            case (tx_state)
                0: begin
                    if (!tx_empty) begin
                        tx_byte <= tx_fifo[tx_rd_ptr];
                        tx_rd_ptr <= (tx_rd_ptr + 1) % FIFO_SIZE;
                        tx_pin <= 0;  // Start bit
                        tx_state <= 1;
                    end
                end
                1: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                2: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                3: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                4: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                5: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                6: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                7: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                8: begin
                    tx_pin <= tx_byte[tx_state - 1];
                    tx_state <= tx_state + 1;
                end
                9: begin
                    tx_pin <= 1;  // Stop bit
                    tx_state <= 0;
                end
                default: tx_state <= 0;
            endcase
        end else begin
            tx_cnt <= tx_cnt + 1;
        end
    end
end

//──────────────────────────────────────────────────────────────────────────────
//  RX FIFO
//──────────────────────────────────────────────────────────────────────────────

reg [7:0] rx_fifo [0:FIFO_SIZE-1];
reg [$clog2(FIFO_SIZE):0] rx_wr_ptr = 0;
reg [$clog2(FIFO_SIZE):0] rx_rd_ptr = 0;
wire rx_empty = (rx_wr_ptr == rx_rd_ptr);
wire rx_full = ((rx_wr_ptr + 1) % FIFO_SIZE == rx_rd_ptr);

// RX state machine
reg [4:0] rx_state = 0;  // 0 idle, 1 start, 2-9 data, 10 stop
reg [7:0] rx_byte = 0;
reg [16:0] rx_cnt = 0;
reg [3:0] rx_bit_cnt = 0;

always @(posedge clk) begin
    if (rst) begin
        rx_state <= 0;
        rx_wr_ptr <= 0;
        rx_cnt <= 0;
        rx_bit_cnt <= 0;
    end else begin
        rx_cnt <= rx_cnt + 1;
        if (rx_cnt == OVERSAMPLE_DIV - 1) begin
            rx_cnt <= 0;
            case (rx_state)
                0: begin
                    if (!rx_pin) begin  // Start bit detected
                        rx_state <= 1;
                        rx_bit_cnt <= 0;
                    end
                end
                1: begin
                    if (rx_bit_cnt == 7) begin  // Sample center
                        rx_byte[rx_bit_cnt] <= rx_pin;
                        rx_bit_cnt <= rx_bit_cnt + 1;
                        if (rx_bit_cnt == 7) rx_state <= 2;
                    end else rx_bit_cnt <= rx_bit_cnt + 1;
                end
                2: begin
                    if (rx_pin) begin  // Stop bit
                        if (!rx_full) begin
                            rx_fifo[rx_wr_ptr] <= rx_byte;
                            rx_wr_ptr <= (rx_wr_ptr + 1) % FIFO_SIZE;
                        end
                        rx_state <= 0;
                    end else rx_state <= 0;  // Framing error
                end
            endcase
        end
    end
end

// RX output
always @(posedge clk) begin
    if (rst) begin
		  rx_valid <= 0;
        rx_rd_ptr <= 0;
    end else if (!rx_empty && rx_ready) begin
        rx_data <= rx_fifo[rx_rd_ptr];
        rx_rd_ptr <= (rx_rd_ptr + 1) % FIFO_SIZE;
        rx_valid <= 1;
    end else rx_valid <= 0;
end

endmodule
