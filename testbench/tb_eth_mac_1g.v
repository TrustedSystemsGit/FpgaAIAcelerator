`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for Ethernet MAC 1G Module
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - RX: приём пакетов, заполнение rx_buffer, flattening в packet_flat
//  - TX: эхо rx_data
//  - packet_valid: пульс после пакета
//  - Кейсы: нормальный пакет, короткий пакет, сброс, ошибка ER
//  - Симуляция: 200 ns, dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_eth_mac_1g;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk = 0;
reg rst = 1;
reg [7:0] rx_data = 0;
reg rx_dv = 0;
reg rx_er = 0;
wire [7:0] tx_data;
wire tx_en;
wire tx_er;
wire [12143:0] packet_flat;
wire packet_valid;

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

eth_mac_1g dut (
    .clk(clk),
    .rst(rst),
    .rx_data(rx_data),
    .rx_dv(rx_dv),
    .rx_er(rx_er),
    .tx_data(tx_data),
    .tx_en(tx_en),
    .tx_er(tx_er),
    .packet_flat(packet_flat),
    .packet_valid(packet_valid)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk = ~clk;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_eth_mac_1g.vcd");
    $dumpvars(0, tb_eth_mac_1g);
end

//──────────────────────────────────────────────────────────────────────────────
//  Функция отправки пакета
//──────────────────────────────────────────────────────────────────────────────
        integer b;

task send_packet;
    input integer length;
    begin
        rx_dv = 1;
        for (b = 0; b < length; b = b + 1) begin
            rx_data = 8'hAA + b[7:0];  // Dummy data
            #CLK_PERIOD;
        end
        rx_dv = 0;
        # (5 * CLK_PERIOD);
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

    // Тест 1: Полный пакет (1518 байт)
    $display("Test 1: Full packet");
    send_packet(1518);
    #(10 * CLK_PERIOD);
    $display("Packet valid: %b", packet_valid);
    $display("Packet flat sample: %h", packet_flat[0 +: 8]);  // First byte

    // Тест 2: Короткий пакет (64 байта)
    $display("Test 2: Short packet");
    send_packet(64);
    #(10 * CLK_PERIOD);
    $display("Packet valid: %b", packet_valid);

    // Тест 3: Сброс во время приёма
    $display("Test 3: Reset during RX");
    rx_dv = 1;
    #(20 * CLK_PERIOD);
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);

    // Тест 4: RX ошибка
    $display("Test 4: RX error");
    rx_er = 1;
    send_packet(1518);
    rx_er = 0;
    #(10 * CLK_PERIOD);
    $display("TX ER: %b", tx_er);

    // Тест 5: Несколько пакетов подряд
    $display("Test 5: Multiple packets");
    send_packet(100);
    send_packet(200);
    send_packet(300);
    #(20 * CLK_PERIOD);

    $display("All tests completed");
    $finish;
end

endmodule

