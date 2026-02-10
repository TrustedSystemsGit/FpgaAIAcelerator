`timescale 1ns / 1ps

//──────────────────────────────────────────────────────────────────────────────
//  Simple Ethernet MAC for 1G - Verilog-2001 версия для ISE 14.7
//──────────────────────────────────────────────────────────────────────────────
//
//  Упрощённая версия: только RX (приём пакетов), flattening packet_data в flat
//
//──────────────────────────────────────────────────────────────────────────────

module eth_mac_1g (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rx_data,
    input  wire        rx_dv,
    input  wire        rx_er,
    output reg  [7:0]  tx_data,
    output reg         tx_en,
    output reg         tx_er,
    output wire [12143:0] packet_flat,  // Flattened output (1518×8 = 12144 бита)
    output reg         packet_valid
);

    //──────────────────────────────────────────────────────────────────────────
    //  Внутренний буфер пакета как память (разрешено внутри модуля)
    //──────────────────────────────────────────────────────────────────────────

    reg [7:0] packet_data [0:1517];
    reg [12:0] ptr = 0;  // Указатель (0..1517)

    //──────────────────────────────────────────────────────────────────────────
    //  Приём пакета (RX)
    //──────────────────────────────────────────────────────────────────────────

    always @(posedge clk) begin
        if (rst) begin
            ptr <= 0;
            packet_valid <= 0;
        end else if (rx_dv) begin
            if (ptr < 1518) begin
                packet_data[ptr] <= rx_data;
                ptr <= ptr + 1;
            end
        end else if (!rx_dv && ptr > 0) begin
            packet_valid <= 1;
            ptr <= 0;  // Сброс после пакета
        end else begin
            packet_valid <= 0;
        end
    end

    //──────────────────────────────────────────────────────────────────────────
    //  Flattening памяти в широкий вектор (используем generate)
    //──────────────────────────────────────────────────────────────────────────

    genvar gi;
    generate
        for (gi = 0; gi < 1518; gi = gi + 1) begin : flatten
            assign packet_flat[8*gi +: 8] = packet_data[gi];
        end
    endgenerate

    //──────────────────────────────────────────────────────────────────────────
    //  TX - заглушка (эхо или пустой)
    //──────────────────────────────────────────────────────────────────────────

    always @(posedge clk) begin
        tx_data <= rx_data;  // Простое эхо
        tx_en   <= rx_dv;
        tx_er   <= rx_er;
    end

endmodule