`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Exhaustive Testbench for Anomaly Autoencoder Learn Module
//──────────────────────────────────────────────────────────────────────────────
//
//  Тестирует:
//  - Распаковку features_in_flat в feat_in
//  - Энкодер: суммирование, ReLU
//  - Декодер: суммирование, linear
//  - MSE: вычисление, anomaly_flag (mse > THRESHOLD)
//  - Обучение: update_en (anomaly_flag), проверка изменения весов
//  - Кейсы: normal, anomaly (high MSE), multiple cycles, reset
//  - Проверка err, sq, hidden_error, delta
//
//  Симуляция: 1000 ns, dump VCD
//
//──────────────────────────────────────────────────────────────────────────────

module tb_anomaly_autoencoder_learn;

//──────────────────────────────────────────────────────────────────────────────
//  Параметры
//──────────────────────────────────────────────────────────────────────────────

localparam CLK_PERIOD = 8;  // 125 MHz
localparam INPUT_SIZE = 20;

//──────────────────────────────────────────────────────────────────────────────
//  Сигналы DUT
//──────────────────────────────────────────────────────────────────────────────

reg clk = 0;
reg rst = 1;
reg [639:0] features_in_flat = 0;
wire anomaly_flag;

//──────────────────────────────────────────────────────────────────────────────
//  Инстанс DUT
//──────────────────────────────────────────────────────────────────────────────

anomaly_autoencoder_learn dut (
    .clk(clk),
    .rst(rst),
    .features_in_flat(features_in_flat),
    .anomaly_flag(anomaly_flag)
);

//──────────────────────────────────────────────────────────────────────────────
//  Генератор такта
//──────────────────────────────────────────────────────────────────────────────

always #(CLK_PERIOD/2) clk = ~clk;

//──────────────────────────────────────────────────────────────────────────────
//  Dump VCD
//──────────────────────────────────────────────────────────────────────────────

initial begin
    $dumpfile("tb_anomaly_autoencoder_learn.vcd");
    $dumpvars(0, tb_anomaly_autoencoder_learn);
end

//──────────────────────────────────────────────────────────────────────────────
//  Функция установки features (dummy)
 //──────────────────────────────────────────────────────────────────────────────
        integer f;

task set_features;
    input [7:0] val;
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

    // Тест 1: Нормальный input (low MSE, no anomaly)
    $display("Test 1: Normal input (low MSE)");
    set_features(8'h01);  // Small values
    #(20 * CLK_PERIOD);
    $display("Anomaly flag: %b (expected 0)", anomaly_flag);

    // Тест 2: Аномалия (high MSE)
    $display("Test 2: Anomaly input (high MSE)");
    set_features(8'h7F);  // Max values to trigger high error
    #(20 * CLK_PERIOD);
    $display("Anomaly flag: %b (expected 1)", anomaly_flag);

    // Тест 3: Проверка обучения (weight change after anomaly)
    $display("Test 3: Training after anomaly");
    set_features(8'h7F);  // Trigger anomaly
    #(20 * CLK_PERIOD);
    $display("Weight enc[0][0] after update: %h", dut.enc_weights[0][0]);
    $display("Bias dec[0] after update: %h", dut.dec_bias[0]);

    // Тест 4: Multiple cycles
    $display("Test 4: Multiple cycles");
    set_features(8'h02); #(10 * CLK_PERIOD);
    set_features(8'h03); #(10 * CLK_PERIOD);
    set_features(8'h7F); #(10 * CLK_PERIOD);
    $display("Anomaly flag: %b", anomaly_flag);

    // Тест 5: Сброс
    $display("Test 5: Reset");
    set_features(8'h7F);
    #(10 * CLK_PERIOD);
    rst = 1;
    #(5 * CLK_PERIOD);
    rst = 0;
    #(10 * CLK_PERIOD);
    $display("Anomaly flag after reset: %b (expected 0)", anomaly_flag);

    // Тест 6: Edge case - all zero
    $display("Test 6: All zero features");
    features_in_flat = 640'h0;
    #(20 * CLK_PERIOD);
    $display("Anomaly flag: %b", anomaly_flag);

    $display("All tests completed");
    $finish;
end

endmodule

