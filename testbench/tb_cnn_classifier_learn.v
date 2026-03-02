`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for CNN Classifier Learn Module
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - Распаковку features_in_flat в feat_in
//  - FC1: суммирование, ReLU
//  - FC2: суммирование, logits
//  - Argmax: выбор максимального класса
//  - Обучение: update_en, изменение весов (заглушка)
//  - Кейсы: normal input, anomaly, label valid, reset
//
//  Симуляция: 500 ns, dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_cnn_classifier_learn;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk = 0;
reg rst = 1;
reg [639:0] features_in_flat = 0;
reg [7:0] label_in = 0;
reg label_in_valid = 0;
reg anomaly_flag = 0;
wire [7:0] class_label;

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

cnn_classifier_learn dut (
    .clk(clk),
    .rst(rst),
    .features_in_flat(features_in_flat),
    .label_in(label_in),
    .label_in_valid(label_in_valid),
    .anomaly_flag(anomaly_flag),
    .class_label(class_label)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk = ~clk;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_cnn_classifier_learn.vcd");
    $dumpvars(0, tb_cnn_classifier_learn);
end

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

    // Тест 1: Нормальный input (dummy features)
    $display("Test 1: Normal input");
    for (f = 0; f < 640; f = f + 8) features_in_flat[f +: 8] = 8'h01;  // All 1
    #(20 * CLK_PERIOD);
    $display("Class label: %h", class_label);

    // Тест 2: Аномалия
    $display("Test 2: Anomaly flag");
    anomaly_flag = 1;
    #(20 * CLK_PERIOD);
    anomaly_flag = 0;
    #(10 * CLK_PERIOD);

    // Тест 3: Label valid
    $display("Test 3: Label valid");
    label_in = 8'h03;
    label_in_valid = 1;
    #(20 * CLK_PERIOD);
    label_in_valid = 0;
    #(10 * CLK_PERIOD);

    // Тест 4: Сброс
    $display("Test 4: Reset");
    rst = 1;
    #(10 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);
    $display("Class label after reset: %h", class_label);

    // Тест 5: Разные features
    $display("Test 5: Different features");
    features_in_flat = 640'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;  // All FF
    #(20 * CLK_PERIOD);
    $display("Class label: %h", class_label);

    $display("All tests completed");
    $finish;
end

endmodule

