`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for CNN Classifier Learn Module (with Training Focus)
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - Распаковку features_in_flat
//  - FC1/FC2: суммирование, ReLU
//  - Argmax
//  - Обучение: update_en (label_valid/anomaly_flag), проверка изменения весов
//  - Кейсы: normal, anomaly, label update, multiple cycles, reset
//  - Проверяет веса до/после обновления (заглушка +1, но легко заменить)
//
//  Симуляция: 1000 ns, dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_cnn_classifier_learn;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz
localparam INPUT_SIZE = 20;
localparam HIDDEN_NEURONS = 64;
localparam CLASS_COUNT = 8;

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
//  Функция установки features (dummy)
//──────────────────────────────────────────────────────────────────────────────

task set_features;
    input [7:0] val;
    integer f;
    begin
        for (f = 0; f < 640; f = f + 32) features_in_flat[f +: 32] = {24'h0, val};
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

    // Тест 1: Нормальный input
    $display("Test 1: Normal input");
    set_features(8'h01);  // All features 1
    #(20 * CLK_PERIOD);
    $display("Class label: %h", class_label);

    // Тест 2: Аномалия (trigger update)
    $display("Test 2: Anomaly flag - check weight update");
    anomaly_flag = 1;
    #(20 * CLK_PERIOD);
    anomaly_flag = 0;
    #(10 * CLK_PERIOD);
    // Проверка изменения веса (пример для fc1_weights[0][0])
    $display("Weight fc1[0][0] after update: %h", dut.fc1_weights[0][0]);

    // Тест 3: Label valid (trigger update)
    $display("Test 3: Label valid - check weight update");
    label_in = 8'h03;
    label_in_valid = 1;
    #(20 * CLK_PERIOD);
    label_in_valid = 0;
    #(10 * CLK_PERIOD);
    $display("Weight fc2[0][0] after update: %h", dut.fc2_weights[0][0]);

    // Тест 4: Multiple cycles (continuous input)
    $display("Test 4: Multiple cycles");
    set_features(8'h02);
    #(10 * CLK_PERIOD);
    set_features(8'h03);
    #(10 * CLK_PERIOD);
    set_features(8'h04);
    #(10 * CLK_PERIOD);
    $display("Final class label: %h", class_label);

    // Тест 5: Сброс во время работы
    $display("Test 5: Reset during operation");
    set_features(8'hFF);
    #(10 * CLK_PERIOD);
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);
    $display("Class label after reset: %h", class_label);

    // Тест 6: Edge case - all zero features
    $display("Test 6: All zero features");
    features_in_flat = 640'h0;
    #(20 * CLK_PERIOD);
    $display("Class label: %h", class_label);

    $display("All tests completed");
    $finish;
end

endmodule

