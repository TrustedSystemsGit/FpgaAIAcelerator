// Copyright (c) 2026 Trusted Systems. MIT License. See LICENSE for details.

`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Anomaly Autoencoder with Online Learning for NIDS - Verilog-2001 версия
//──────────────────────────────────────────────────────────────────────────────
//
//  Вход: features_in_flat [639:0] - 20 признаков × 32 бита = 640 бит
//  Внутри: распаковка в массив feat_in [0:19] через generate
//
//──────────────────────────────────────────────────────────────────────────────

module anomaly_autoencoder_learn (
    input  wire        clk,
    input  wire        rst,

    input  wire [639:0] features_in_flat,     // 20 × 32 = 640 бит (0..639)

    output reg         anomaly_flag
);

    localparam THRESHOLD     = 100;
    localparam LR            = 1;
    localparam SHIFT         = 10;
    localparam INPUT_SIZE    = 20;
    localparam HIDDEN_SIZE   = 10;

    //──────────────────────────────────────────────────────────────────────────
    //  Веса энкодера [hidden][input]
    //──────────────────────────────────────────────────────────────────────────

    reg signed [7:0] enc_weights [0:HIDDEN_SIZE-1][0:INPUT_SIZE-1];
    reg signed [7:0] enc_bias [0:HIDDEN_SIZE-1];

    //──────────────────────────────────────────────────────────────────────────
    //  Веса декодера [output][hidden]
    //──────────────────────────────────────────────────────────────────────────

    reg signed [7:0] dec_weights [0:INPUT_SIZE-1][0:HIDDEN_SIZE-1];
    reg signed [7:0] dec_bias [0:INPUT_SIZE-1];

    //──────────────────────────────────────────────────────────────────────────
    //  Переменная для циклов (одна на весь модуль)
    //──────────────────────────────────────────────────────────────────────────

    integer i;

    //──────────────────────────────────────────────────────────────────────────
    //  Инициализация весов (маленькие случайные значения)
    //──────────────────────────────────────────────────────────────────────────
            integer j;

    initial begin
        for (i = 0; i < HIDDEN_SIZE; i = i + 1) begin
            for (j = 0; j < INPUT_SIZE; j = j + 1) begin
                enc_weights[i][j] = $signed($random % 10);
            end
            enc_bias[i] = 0;
        end

        for (i = 0; i < INPUT_SIZE; i = i + 1) begin
            for (j = 0; j < HIDDEN_SIZE; j = j + 1) begin
                dec_weights[i][j] = $signed($random % 10);
            end
            dec_bias[i] = 0;
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    //  Распаковка features_in_flat [639:0] → feat_in [0:19] (младшие 8 бит)
    //──────────────────────────────────────────────────────────────────────────

    wire signed [7:0] feat_in [0:INPUT_SIZE-1];

    genvar f;
    generate
        for (f = 0; f < INPUT_SIZE; f = f + 1) begin : unpack_features
            assign feat_in[f] = features_in_flat[32*f +: 8];  // младшие 8 бит каждого 32-битного признака
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Энкодер: feat_in → hidden
    //──────────────────────────────────────────────────────────────────────────

    wire signed [7:0] hidden [0:HIDDEN_SIZE-1];

    genvar h;
    generate
        for (h = 0; h < HIDDEN_SIZE; h = h + 1) begin : enc_layer
            reg signed [15:0] sum_enc;
            always @(*) begin
                sum_enc = enc_bias[h] << 8;
                for (i = 0; i < INPUT_SIZE; i = i + 1) begin
                    sum_enc = sum_enc + feat_in[i] * enc_weights[h][i];
                end
            end
            assign hidden[h] = (sum_enc >> 8 > 0) ? (sum_enc >> 8) : 8'sh0;  // ReLU
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Декодер: hidden → recon
    //──────────────────────────────────────────────────────────────────────────

    wire signed [15:0] recon [0:INPUT_SIZE-1];

    genvar o;
    generate
        for (o = 0; o < INPUT_SIZE; o = o + 1) begin : dec_layer
            reg signed [15:0] sum_dec;
            always @(*) begin
                sum_dec = dec_bias[o] << 8;
                for (i = 0; i < HIDDEN_SIZE; i = i + 1) begin
                    sum_dec = sum_dec + hidden[i] * dec_weights[o][i];
                end
            end
            assign recon[o] = sum_dec >> 8;  // Линейный выход
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Вычисление ошибок и квадратов
    //──────────────────────────────────────────────────────────────────────────

    wire signed [7:0] err [0:INPUT_SIZE-1];
    wire [15:0] sq [0:INPUT_SIZE-1];

    genvar e;
    generate
        for (e = 0; e < INPUT_SIZE; e = e + 1) begin : mse_calc
            assign err[e] = feat_in[e] - recon[e];
            assign sq[e]  = err[e] * err[e];
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  MSE - только non-blocking присваивания
    //──────────────────────────────────────────────────────────────────────────

    reg [15:0] mse;
    reg [15:0] temp_mse;

    always @(posedge clk) begin
        if (rst) begin
            mse <= 16'h0000;
            temp_mse <= 16'h0000;
        end else begin
            temp_mse <= 0;
            for (i = 0; i < INPUT_SIZE; i = i + 1) begin
                temp_mse <= temp_mse + sq[i];
            end
            mse <= temp_mse;
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    //  Флаг аномалии
    //──────────────────────────────────────────────────────────────────────────

    always @(posedge clk) begin
        if (rst) anomaly_flag <= 1'b0;
        else anomaly_flag <= (mse > THRESHOLD) ? 1'b1 : 1'b0;
    end

    //──────────────────────────────────────────────────────────────────────────
    //  Backpropagation и обновление весов (без изменений)
    //──────────────────────────────────────────────────────────────────────────

    wire signed [15:0] hidden_error [0:HIDDEN_SIZE-1];

    genvar he;
    generate
        for (he = 0; he < HIDDEN_SIZE; he = he + 1) begin : hidden_err_calc
            reg signed [15:0] sum_err;
            always @(*) begin
                sum_err = 0;
                for (i = 0; i < INPUT_SIZE; i = i + 1) begin
                    sum_err = sum_err + err[i] * dec_weights[i][he];
                end
            end
            wire signed [7:0] sig_prime = (hidden[he] * (8'sh7F - hidden[he])) >> 7;
            assign hidden_error[he] = (sum_err >> 8) * sig_prime;
        end
    endgenerate

    // Update decoder
    genvar ud_o, ud_h;
    generate
        for (ud_o = 0; ud_o < INPUT_SIZE; ud_o = ud_o + 1) begin : update_dec_o
            for (ud_h = 0; ud_h < HIDDEN_SIZE; ud_h = ud_h + 1) begin : update_dec_h
                wire signed [15:0] delta = (err[ud_o] * hidden[ud_h] * LR) >> SHIFT;
                always @(posedge clk) begin
                    if (anomaly_flag) dec_weights[ud_o][ud_h] <= dec_weights[ud_o][ud_h] + delta[7:0];
                end
            end
        end
    endgenerate

    // Update encoder
    genvar ue_h, ue_i;
    generate
        for (ue_h = 0; ue_h < HIDDEN_SIZE; ue_h = ue_h + 1) begin : update_enc_h
            for (ue_i = 0; ue_i < INPUT_SIZE; ue_i = ue_i + 1) begin : update_enc_i
                wire signed [15:0] delta = (hidden_error[ue_h] * feat_in[ue_i] * LR) >> SHIFT;
                always @(posedge clk) begin
                    if (anomaly_flag) enc_weights[ue_h][ue_i] <= enc_weights[ue_h][ue_i] + delta[7:0];
                end
            end
        end
    endgenerate

    // Update bias
    genvar ub_h;
    generate
        for (ub_h = 0; ub_h < HIDDEN_SIZE; ub_h = ub_h + 1) begin : update_enc_bias
            always @(posedge clk) begin
                if (anomaly_flag) enc_bias[ub_h] <= enc_bias[ub_h] + hidden_error[ub_h];
            end
        end
    endgenerate

    genvar ub_o;
    generate
        for (ub_o = 0; ub_o < INPUT_SIZE; ub_o = ub_o + 1) begin : update_dec_bias
            always @(posedge clk) begin
                if (anomaly_flag) dec_bias[ub_o] <= dec_bias[ub_o] + err[ub_o];
            end
        end
    endgenerate

endmodule
