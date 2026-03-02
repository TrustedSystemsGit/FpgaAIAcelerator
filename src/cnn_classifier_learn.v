`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  CNN Classifier with Online Learning for NIDS - Verilog-2001 версия
//──────────────────────────────────────────────────────────────────────────────

module cnn_classifier_learn (
    input  wire        clk,
    input  wire        rst,

    input  wire [639:0] features_in_flat,   // 20 × 32 = 640 бит

    input  wire [7:0]  label_in,
    input  wire        label_in_valid,
    input  wire        anomaly_flag,

    output reg  [7:0]  class_label
);

    localparam INPUT_SIZE     = 20;
    localparam HIDDEN_NEURONS = 4;
    localparam CLASS_COUNT    = 8;
    localparam LR             = 1;
    localparam SHIFT          = 10;

    //──────────────────────────────────────────────────────────────────────────
    //  Переменные для всех циклов и инициализации (объявлены один раз)
    //──────────────────────────────────────────────────────────────────────────

    integer init_h, init_i, init_c;
    integer h_fc1, i_fc1, c_fc2, h_fc2;

    //──────────────────────────────────────────────────────────────────────────
    //  Распаковка входных признаков (младшие 8 бит)
    //──────────────────────────────────────────────────────────────────────────

    wire signed [7:0] feat_in [0:INPUT_SIZE-1];

    genvar fi;
    generate
        for (fi = 0; fi < INPUT_SIZE; fi = fi + 1) begin : unpack_features
            assign feat_in[fi] = features_in_flat[32*fi +: 8];
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Веса FC1 [hidden][input] = 64 × 20 = 1280
    //──────────────────────────────────────────────────────────────────────────

    reg signed [7:0] fc1_weights [0:HIDDEN_NEURONS-1][0:INPUT_SIZE-1];
    reg signed [7:0] fc1_bias [0:HIDDEN_NEURONS-1];

    //──────────────────────────────────────────────────────────────────────────
    //  Веса FC2 [class][hidden] = 8 × 64 = 512
    //──────────────────────────────────────────────────────────────────────────

    reg signed [7:0] fc2_weights [0:CLASS_COUNT-1][0:HIDDEN_NEURONS-1];
    reg signed [7:0] fc2_bias [0:CLASS_COUNT-1];

    //──────────────────────────────────────────────────────────────────────────
    //  Инициализация весов
    //──────────────────────────────────────────────────────────────────────────

    initial begin
        for (init_h = 0; init_h < HIDDEN_NEURONS; init_h = init_h + 1) begin
            for (init_i = 0; init_i < INPUT_SIZE; init_i = init_i + 1) begin
                fc1_weights[init_h][init_i] = (init_h + init_i) % 10;  // 0..9
            end
        end

        for (init_c = 0; init_c < CLASS_COUNT; init_c = init_c + 1) begin
            for (init_h = 0; init_h < HIDDEN_NEURONS; init_h = init_h + 1) begin
                fc2_weights[init_c][init_h] = (init_c + init_h) % 10;  // 0..9
            end
        end
    end
    //──────────────────────────────────────────────────────────────────────────
    //  FC1: feat_in → hidden (generate для отдельных сумм)
    //──────────────────────────────────────────────────────────────────────────

    wire signed [15:0] hidden [0:HIDDEN_NEURONS-1];

    genvar h;
    generate
        for (h = 0; h < HIDDEN_NEURONS; h = h + 1) begin : fc1_layer
            reg signed [15:0] sum_fc1;
            always @(*) begin
                sum_fc1 = fc1_bias[h] << 8;
                for (i_fc1 = 0; i_fc1 < INPUT_SIZE; i_fc1 = i_fc1 + 1) begin
                    sum_fc1 = sum_fc1 + feat_in[i_fc1] * fc1_weights[h][i_fc1];
                end
            end
            assign hidden[h] = (sum_fc1 >> 8 > 0) ? (sum_fc1 >> 8) : 8'sh00;  // ReLU
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  FC2: hidden → logits (generate для отдельных сумм)
    //──────────────────────────────────────────────────────────────────────────

    wire signed [7:0] logits [0:CLASS_COUNT-1];

    genvar c;
    generate
        for (c = 0; c < CLASS_COUNT; c = c + 1) begin : fc2_layer
            reg signed [15:0] sum_fc2;
            always @(*) begin
                sum_fc2 = fc2_bias[c] << 8;
                for (h_fc2 = 0; h_fc2 < HIDDEN_NEURONS; h_fc2 = h_fc2 + 1) begin
                    sum_fc2 = sum_fc2 + hidden[h_fc2] * fc2_weights[c][h_fc2];
                end
            end
            assign logits[c] = sum_fc2[15:8];  // Equivalent to arithmetic >> 8
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Argmax - последовательные сравнения (без цикла for)
    //──────────────────────────────────────────────────────────────────────────
            reg signed [7:0] max_val;
            reg [2:0] max_idx;


    always @(posedge clk) begin
        if (rst) begin
            class_label <= 8'h00;
        end else begin
            max_val = logits[0];
            max_idx = 3'd0;

            if (logits[1] > max_val) begin max_val = logits[1]; max_idx = 3'd1; end
            if (logits[2] > max_val) begin max_val = logits[2]; max_idx = 3'd2; end
            if (logits[3] > max_val) begin max_val = logits[3]; max_idx = 3'd3; end
            if (logits[4] > max_val) begin max_val = logits[4]; max_idx = 3'd4; end
            if (logits[5] > max_val) begin max_val = logits[5]; max_idx = 3'd5; end
            if (logits[6] > max_val) begin max_val = logits[6]; max_idx = 3'd6; end
            if (logits[7] > max_val) begin max_val = logits[7]; max_idx = 3'd7; end

            class_label <= max_idx;
        end
    end
    
    //──────────────────────────────────────────────────────────────────────────
    //  Обучение: полный SGD с backprop (update if label_in_valid)
    //──────────────────────────────────────────────────────────────────────────

    wire update_en = label_in_valid;  // Supervised only

    // One-hot target from label_in (wire array)
    wire signed [7:0] target [0:CLASS_COUNT-1];

    genvar t;
    generate
        for (t = 0; t < CLASS_COUNT; t = t + 1) begin : one_hot
            assign target[t] = (label_in == t) ? 8'sh7F : 8'sh00;  // Approx 1/0
        end
    endgenerate

    // Output error = logits - target (approx for cross-entropy)
    wire signed [7:0] output_error [0:CLASS_COUNT-1];

    genvar oe;
    generate
        for (oe = 0; oe < CLASS_COUNT; oe = oe + 1) begin : out_err
            assign output_error[oe] = logits[oe] - target[oe];
        end
    endgenerate

    // Hidden error = sum(output_error * fc2_weights) * derivative(ReLU)
    wire signed [7:0] hidden_error [0:HIDDEN_NEURONS-1];

    genvar he;
	 integer oe_i;
    generate
        for (he = 0; he < HIDDEN_NEURONS; he = he + 1) begin : hid_err
            reg signed [15:0] sum_he;
            always @(*) begin
                sum_he = 0;
                for (oe_i = 0; oe_i < CLASS_COUNT; oe_i = oe_i + 1) begin
                    sum_he = sum_he + output_error[oe_i] * fc2_weights[oe_i][he];
                end
            end
            wire signed [7:0] relu_deriv = (hidden[he] > 0) ? 8'sh7F : 8'sh00;  // 1 or 0 approx
				wire signed [15:0] temp_expr = (sum_he >> 8) * relu_deriv >> 7;
            assign hidden_error[he] = temp_expr[7:0];
		  end
    endgenerate

    // Update fc2_weights: fc2_weights[c][h] += (output_error[c] * hidden[h] * LR) >> SHIFT
    genvar u_c, u_h2;
    generate
        for (u_c = 0; u_c < CLASS_COUNT; u_c = u_c + 1) begin : update_fc2
            for (u_h2 = 0; u_h2 < HIDDEN_NEURONS; u_h2 = u_h2 + 1) begin : update_fc2_h
                wire signed [15:0] delta = (output_error[u_c] * hidden[u_h2] * LR) >> SHIFT;
                always @(posedge clk) begin
                    if (update_en) fc2_weights[u_c][u_h2] <= fc2_weights[u_c][u_h2] + delta[7:0];
                end
            end
            // Bias update
            always @(posedge clk) begin
                if (update_en) fc2_bias[u_c] <= fc2_bias[u_c] + output_error[u_c];
            end
        end
    endgenerate

    // Update fc1_weights: fc1_weights[h][i] += (hidden_error[h] * feat_in[i] * LR) >> SHIFT
    genvar u_h, u_i;
    generate
        for (u_h = 0; u_h < HIDDEN_NEURONS; u_h = u_h + 1) begin : update_fc1
            for (u_i = 0; u_i < INPUT_SIZE; u_i = u_i + 1) begin : update_fc1_in
                wire signed [15:0] delta = (hidden_error[u_h] * feat_in[u_i] * LR) >> SHIFT;
                always @(posedge clk) begin
                    if (update_en) fc1_weights[u_h][u_i] <= fc1_weights[u_h][u_i] + delta[7:0];
                end
            end
            // Bias update
            always @(posedge clk) begin
                if (update_en) fc1_bias[u_h] <= fc1_bias[u_h] + hidden_error[u_h];
            end
        end
    endgenerate

endmodule
