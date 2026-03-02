`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Packet Parser для NIDS - версия с flattened выходом
//──────────────────────────────────────────────────────────────────────────────
//
//  Выход: features_flat [639:0] = 20×32 = 640 бит (0..639)
//  Внутренние features как массив, flattening через generate
//
//──────────────────────────────────────────────────────────────────────────────

module packet_parser (
    input  wire        clk,
    input  wire        rst,
    input  wire [12143:0] packet_in_flat,     // 1518×8 = 12144 бита
    input  wire        valid_in,
    output wire [639:0] features_flat         // Flattened 20×32 = 640 бит
);

    //──────────────────────────────────────────────────────────────────────────
    //  Внутренние признаки как массив
    //──────────────────────────────────────────────────────────────────────────

    reg [31:0] features [0:19];

    //──────────────────────────────────────────────────────────────────────────
    //  Распаковка packet_in_flat (пример generate для первых байт)
    //──────────────────────────────────────────────────────────────────────────

    wire [7:0] packet_in [0:1517];

    genvar gi;
    generate
        for (gi = 0; gi < 1518; gi = gi + 1) begin : unpack
            assign packet_in[gi] = packet_in_flat[8*gi +: 8];
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  Выделение полей
    //──────────────────────────────────────────────────────────────────────────

    wire [47:0] dst_mac = {packet_in[0], packet_in[1], packet_in[2], packet_in[3], packet_in[4], packet_in[5]};
    wire [47:0] src_mac = {packet_in[6], packet_in[7], packet_in[8], packet_in[9], packet_in[10], packet_in[11]};
    wire [15:0] eth_type = {packet_in[12], packet_in[13]};

    wire [7:0]  version_ihl = packet_in[14];
    wire [7:0]  tos         = packet_in[15];
    wire [15:0] ip_length   = {packet_in[16], packet_in[17]};
    wire [15:0] id          = {packet_in[18], packet_in[19]};
    wire [15:0] flags_frag  = {packet_in[20], packet_in[21]};
    wire [7:0]  ttl         = packet_in[22];
    wire [7:0]  protocol    = packet_in[23];
    wire [15:0] checksum    = {packet_in[24], packet_in[25]};
    wire [31:0] src_ip      = {packet_in[26], packet_in[27], packet_in[28], packet_in[29]};
    wire [31:0] dst_ip      = {packet_in[30], packet_in[31], packet_in[32], packet_in[33]};
    wire [15:0] src_port    = {packet_in[34], packet_in[35]};
    wire [15:0] dst_port    = {packet_in[36], packet_in[37]};

    //──────────────────────────────────────────────────────────────────────────
    //  Логика парсинга
    //──────────────────────────────────────────────────────────────────────────

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 20; i = i + 1) features[i] <= 32'h0;
        end else if (valid_in) begin
            features[14] <= dst_mac[31:0];
            features[15] <= {16'h0, dst_mac[47:32]};
            features[16] <= src_mac[31:0];
            features[17] <= {16'h0, src_mac[47:32]};
            features[18] <= {16'h0, eth_type};
            features[19] <= 32'h1;  // placeholder

            if (eth_type == 16'h0800) begin
                features[0]  <= src_ip;
                features[1]  <= dst_ip;
                features[6]  <= {24'h0, tos};
                features[7]  <= {24'h0, ttl};
                features[8]  <= {16'h0, flags_frag};
                features[9]  <= {16'h0, checksum};
                features[10] <= {24'h0, version_ihl};
                features[11] <= {24'h0, id[15:8]};
                features[12] <= {24'h0, id[7:0]};
                features[13] <= {24'h0, flags_frag[7:0]};
                features[4]  <= {16'h0, ip_length};
                features[5]  <= {24'h0, protocol};

                if (protocol == 6 || protocol == 17) begin
                    features[2] <= {16'h0, src_port};
                    features[3] <= {16'h0, dst_port};
                end else begin
                    features[2] <= 32'h0;
                    features[3] <= 32'h0;
                end
            end else begin
                for (i = 0; i < 14; i = i + 1) features[i] <= 32'h0;
            end
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    //  Flattening features [0:19] в [639:0]
    //──────────────────────────────────────────────────────────────────────────

    genvar gf;
    generate
        for (gf = 0; gf < 20; gf = gf + 1) begin : flatten_features
            assign features_flat[32*gf +: 32] = features[gf];
        end
    endgenerate

endmodule