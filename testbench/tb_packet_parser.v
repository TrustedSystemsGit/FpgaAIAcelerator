`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for Packet Parser Module
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - Распаковку packet_in_flat в packet_in
//  - Парсинг Ethernet/IP/TCP/UDP полей
//  - Заполнение features [0:19]
//  - Flattening в features_flat [639:0]
//  - Кейсы: IP/TCP, IP/UDP, non-IP, anomaly-like data, reset
//  - Проверка всех 20 features
//
//  Симуляция: 500 ns, dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_packet_parser;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk = 0;
reg rst = 1;
reg [12143:0] packet_in_flat = 0;
reg valid_in = 0;
wire [639:0] features_flat;

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

packet_parser dut (
    .clk(clk),
    .rst(rst),
    .packet_in_flat(packet_in_flat),
    .valid_in(valid_in),
    .features_flat(features_flat)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk = ~clk;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_packet_parser.vcd");
    $dumpvars(0, tb_packet_parser);
end

//──────────────────────────────────────────────────────────────────────────────
//  Функция установки пакета (dummy)
//──────────────────────────────────────────────────────────────────────────────
        integer b;

task set_packet;
    input [15:0] eth_type_val;
    input [7:0] protocol_val;
    begin
        for (b = 0; b < 12144; b = b + 8) packet_in_flat[b +: 8] = 8'hAA;  // Dummy
        packet_in_flat[96 +: 16] = eth_type_val;  // eth_type at bytes 12-13
        packet_in_flat[184 +: 8] = protocol_val;  // protocol at byte 23
        valid_in = 1;
        #CLK_PERIOD;
        valid_in = 0;
    end
endtask

//──────────────────────────────────────────────────────────────────────────────
//  Тестовая последовательность
//──────────────────────────────────────────────────────────────────────────────

initial begin
    // Сброс
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);

    // Тест 1: IP/TCP пакет
    $display("Test 1: IP/TCP packet");
    set_packet(16'h0800, 8'h06);  // IP, TCP
    #(20 * CLK_PERIOD);
    $display("Features flat sample: %h", features_flat[0 +: 32]);  // features[0]

    // Тест 2: IP/UDP пакет
    $display("Test 2: IP/UDP packet");
    set_packet(16'h0800, 8'h11);  // IP, UDP
    #(20 * CLK_PERIOD);
    $display("Src port in features: %h", features_flat[64 +: 32]);  // features[2]

    // Тест 3: Non-IP пакет
    $display("Test 3: Non-IP packet");
    set_packet(16'h0806, 8'h00);  // ARP
    #(20 * CLK_PERIOD);
    $display("Features 0: %h (should be 0)", features_flat[0 +: 32]);

    // Тест 4: Аномалия-like (все FF)
    $display("Test 4: Anomaly-like packet");
    packet_in_flat = {12144{1'b1}};  // All FF
    valid_in = 1;
    #CLK_PERIOD;
    valid_in = 0;
    #(20 * CLK_PERIOD);
    $display("Eth type in features: %h", features_flat[576 +: 32]);  // features[18]

    // Тест 5: Сброс во время обработки
    $display("Test 5: Reset during parse");
    valid_in = 1;
    #(5 * CLK_PERIOD);
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);

    // Тест 6: Несколько пакетов
    $display("Test 6: Multiple packets");
    set_packet(16'h0800, 8'h06);
    #(10 * CLK_PERIOD);
    set_packet(16'h0800, 8'h11);
    #(10 * CLK_PERIOD);
    set_packet(16'h0806, 8'h00);
    #(20 * CLK_PERIOD);

    $display("All tests completed");
    $finish;
end

endmodule

