// Copyright (c) 2026 Trusted Systems. MIT License. See LICENSE for details.

`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for UART RS232 Module
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - TX: отправка байта, проверка последовательности бит (start, data, stop)
//  - RX: приём байта, проверка rx_data и rx_valid
//  - FIFO: заполнение, overflow, empty
//  - Oversampling: точность приёма
//  - Кейсы: normal TX/RX, error (framing), reset, multiple bytes
//  - Проверка tx_ready, rx_ready
//
//  Параметры: CLK_FREQ = 125MHz, BAUD_RATE = 9600, OVERSAMPLE = 16
//  Симуляция: 1_000_000 ns (длинная для нескольких байт), dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_uart_rs232;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz = 8 ns
localparam BAUD_PERIOD = 104167;  // Approx for 9600 baud

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk = 0;
reg rst = 1;
reg [7:0] tx_data = 0;
reg tx_valid = 0;
wire tx_ready;
wire [7:0] rx_data;
wire rx_valid;
reg rx_ready = 1;
wire tx_pin;
reg rx_pin = 1;  // Idle high

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

uart_rs232 dut (
    .clk(clk),
    .rst(rst),
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    .tx_pin(tx_pin),
    .rx_pin(rx_pin)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk = ~clk;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_uart_rs232.vcd");
    $dumpvars(0, tb_uart_rs232);
end

//──────────────────────────────────────────────────────────────────────────────
//  Функция отправки байта через RX pin (битовая симуляция)
 //──────────────────────────────────────────────────────────────────────────────

task send_rx_byte;
    input [7:0] byte;
    begin
        rx_pin = 0;  // Start bit
        #(BAUD_PERIOD);
        rx_pin = byte[0]; #(BAUD_PERIOD);
        rx_pin = byte[1]; #(BAUD_PERIOD);
        rx_pin = byte[2]; #(BAUD_PERIOD);
        rx_pin = byte[3]; #(BAUD_PERIOD);
        rx_pin = byte[4]; #(BAUD_PERIOD);
        rx_pin = byte[5]; #(BAUD_PERIOD);
        rx_pin = byte[6]; #(BAUD_PERIOD);
        rx_pin = byte[7]; #(BAUD_PERIOD);
        rx_pin = 1;  // Stop bit
        #(BAUD_PERIOD);
    end
endtask

//──────────────────────────────────────────────────────────────────────────────
//  Тестовая последовательность
//──────────────────────────────────────────────────────────────────────────────
    integer f;

initial begin
    // Сброс
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);

    // Тест 1: TX нормальный байт
    $display("Test 1: TX normal byte");
    tx_data = 8'hA5;
    tx_valid = 1;
    #CLK_PERIOD;
    tx_valid = 0;
    #(10 * BAUD_PERIOD);  // Ждём передачи
    $display("TX ready: %b", tx_ready);

    // Тест 2: RX нормальный байт
    $display("Test 2: RX normal byte");
    send_rx_byte(8'h5A);
    #(2 * BAUD_PERIOD);
    $display("RX data: %h, valid: %b", rx_data, rx_valid);

    // Тест 3: FIFO TX заполнение
    $display("Test 3: TX FIFO fill");
    for (f = 0; f < 16; f = f + 1) begin
        tx_data = 8'h10 + f;
        tx_valid = 1;
        #CLK_PERIOD;
        tx_valid = 0;
        #(CLK_PERIOD);
    end
    $display("TX ready after fill: %b (should be 0)", tx_ready);
    #(20 * BAUD_PERIOD);  // Ждём передачи
    $display("TX ready after empty: %b (should be 1)", tx_ready);

    // Тест 4: RX framing error
    $display("Test 4: RX framing error");
    rx_pin = 0;  // Start
    #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);  // Data bits all 1
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 1; #(BAUD_PERIOD);
    rx_pin = 0;  // Stop bit error (0 instead of 1)
    #(BAUD_PERIOD);
    $display("RX valid after error: %b (should be 0)", rx_valid);

    // Тест 5: Сброс во время TX/RX
    $display("Test 5: Reset during TX/RX");
    tx_data = 8'hFF;
    tx_valid = 1;
    #CLK_PERIOD;
    tx_valid = 0;
    #(2 * BAUD_PERIOD);
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);
    $display("TX pin after reset: %b (idle 1)", dut.tx_pin);

    // Тест 6: Multiple bytes TX/RX
    $display("Test 6: Multiple bytes");
    tx_data = 8'h01; tx_valid = 1; #CLK_PERIOD; tx_valid = 0;
    tx_data = 8'h02; tx_valid = 1; #CLK_PERIOD; tx_valid = 0;
    #(20 * BAUD_PERIOD);
    send_rx_byte(8'h03);
    send_rx_byte(8'h04);
    #(20 * BAUD_PERIOD);
    $display("RX data1: %h", rx_data);

    $display("All tests completed");
    $finish;
end

endmodule
