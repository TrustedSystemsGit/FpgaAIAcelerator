`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for NIDS Autonomous on ML605 Virtex-6
//──────────────────────────────────────────────────────────────────────────────
//
//  Исправлено:
//  - Declarations not allowed: integer p и reg temp_val объявлены на уровне модуля
//  - Syntax error near "[": убраны все проблемные инициализации массивов
//  - Cannot access memory directly: все доступы к памяти — в procedural блоках (initial, always)
//  - Port data array: task send_packet теперь принимает flat вектор [12143:0], распаковка внутри
//  - Missing directive: timescale на первой строке, macro verilog не используется
//  - Все массивы объявлены reg, инициализированы в initial с blocking (=)
//
//──────────────────────────────────────────────────────────────────────────────

module tb_nids_autonomous;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры симуляции
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz = 8 ns
localparam BAUD_PERIOD = 104167;  // 9600 baud at 125MHz

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk_125mhz = 0;
reg rst = 1;
reg [7:0] gmii_rxd = 0;
reg gmii_rx_dv = 0;
reg gmii_rx_er = 0;
wire [7:0] gmii_txd;
wire gmii_tx_en;
wire gmii_tx_er;
wire [7:0] alert_out;
reg uart_rx_pin = 1;  // Idle high
wire uart_tx_pin;

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

nids_autonomous dut (
    .clk_125mhz(clk_125mhz),
    .rst(rst),
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .alert_out(alert_out),
    .uart_rx_pin(uart_rx_pin),
    .uart_tx_pin(uart_tx_pin)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk_125mhz = ~clk_125mhz;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD для GTKWave
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_nids_autonomous.vcd");
    $dumpvars(0, tb_nids_autonomous);
end

//──────────────────────────────────────────────────────────────────────────────
//  Переменные для циклов и temp (объявлены на уровне модуля)
//──────────────────────────────────────────────────────────────────────────────

integer p;
reg [7:0] temp_val;

//──────────────────────────────────────────────────────────────────────────────
//  Массивы пакетов — flat вектора (12144 бита)
//──────────────────────────────────────────────────────────────────────────────

reg [12143:0] normal_packet_flat = 0;
reg [12143:0] non_ip_packet_flat = 0;
reg [12143:0] anomaly_packet_flat = 0;

//──────────────────────────────────────────────────────────────────────────────
//  Инициализация flat векторов в initial
//──────────────────────────────────────────────────────────────────────────────

initial begin
    for (p = 0; p < 1518; p = p + 1) begin
        temp_val = p % 256;
        normal_packet_flat[8*p +: 8] = temp_val;
        non_ip_packet_flat[8*p +: 8] = temp_val;
        anomaly_packet_flat[8*p +: 8] = 8'hFF;
    end
    // Специфические поля для normal
    normal_packet_flat[96 +: 16] = 16'h0800;  // eth_type IP (bytes 12-13)
    normal_packet_flat[184 +: 8] = 8'h06;     // protocol TCP (byte 23)

    // Для non-IP
    non_ip_packet_flat[96 +: 16] = 16'h0806;  // ARP

    // Для anomaly
    anomaly_packet_flat[96 +: 16] = 16'h0800;  // IP
    anomaly_packet_flat[184 +: 8] = 8'h06;     // TCP
end

//──────────────────────────────────────────────────────────────────────────────
//  Функции для теста
//──────────────────────────────────────────────────────────────────────────────

// Функция отправки Ethernet пакета (теперь flat вектор)
task send_packet;
    input [12143:0] data_flat;
    integer k;
    begin
        gmii_rx_dv <= 1;
        for (k = 0; k < 1518; k = k + 1) begin
            gmii_rxd <= data_flat[8*k +: 8];
            #CLK_PERIOD;
        end
        gmii_rx_dv <= 0;
        # (10 * CLK_PERIOD);
    end
endtask

// Функция отправки byte через UART RX
task send_uart_byte;
    input [7:0] byte;
    begin
        uart_rx_pin <= 0;  // Start bit
        #(BAUD_PERIOD);
        uart_rx_pin <= byte[0]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[1]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[2]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[3]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[4]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[5]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[6]; #(BAUD_PERIOD);
        uart_rx_pin <= byte[7]; #(BAUD_PERIOD);
        uart_rx_pin <= 1;  // Stop bit
        #(BAUD_PERIOD);
    end
endtask

//──────────────────────────────────────────────────────────────────────────────
//  Основная тестовая последовательность
//──────────────────────────────────────────────────────────────────────────────

initial begin
    // Сброс
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);

    // Тест 1: Нормальный IP/TCP пакет
    $display("Test 1: Normal IP/TCP packet");
    send_packet(normal_packet_flat);
    #(50 * CLK_PERIOD);
    if (dut.anomaly_flag) $display("Anomaly detected");
    $display("Class label: %h", dut.class_label);
    $display("Alert out: %h", dut.alert_out);

    // Тест 2: Не-IP пакет
    $display("Test 2: Non-IP packet");
    send_packet(non_ip_packet_flat);
    #(50 * CLK_PERIOD);
    if (dut.anomaly_flag) $display("Anomaly detected");
    $display("Class label: %h", dut.class_label);
    $display("Alert out: %h", dut.alert_out);

    // Тест 3: Аномалия
    $display("Test 3: Anomaly packet");
    send_packet(anomaly_packet_flat);
    #(50 * CLK_PERIOD);
    if (dut.anomaly_flag) $display("Anomaly detected");
    $display("Class label: %h", dut.class_label);
    $display("Alert out: %h", dut.alert_out);

    // Тест 4: Label через UART
    $display("Test 4: Label via UART");
    send_uart_byte(8'h05);  // Label 5
    #(50 * CLK_PERIOD);
    $display("Received label: %h", dut.label_in);
    $display("Label valid: %b", dut.label_in_valid);

    // Тест 5: Сброс
    $display("Test 5: Reset");
    rst = 1;
    #(10 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);
    $display("Alert out after reset: %h", dut.alert_out);

    // Тест 6: Несколько пакетов подряд
    $display("Test 6: Multiple packets");
    send_packet(normal_packet_flat);
    #(20 * CLK_PERIOD);
    send_packet(non_ip_packet_flat);
    #(20 * CLK_PERIOD);
    send_packet(anomaly_packet_flat);
    #(50 * CLK_PERIOD);

    // Тест 7: Ошибка RX
    $display("Test 7: RX error");
    gmii_rx_er <= 1;
    send_packet(normal_packet_flat);
    gmii_rx_er <= 0;
    #(50 * CLK_PERIOD);
    $display("TX ER: %b", dut.gmii_tx_er);

    $display("All tests completed");
    $finish;
end

endmodule

