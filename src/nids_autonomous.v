`timescale 1ns / 1ps
// Top-level module for autonomous NIDS on ML605 Virtex-6
// Integrates Ethernet MAC, Packet parser, CNN classifier, Anomaly autoencoder, UART
module nids_autonomous (
    input clk_125mhz,
    input rst,
    input [7:0] gmii_rxd,
    input gmii_rx_dv,
    input gmii_rx_er,
    output [7:0] gmii_txd,
    output gmii_tx_en,
    output gmii_tx_er,
    output reg [7:0] alert_out,
//    input [7:0] label_in,
//    input label_in_valid,
    input uart_rx_pin,  // Added UART input
    output uart_tx_pin  // Added UART output
);
    // Internal signals
    wire [12143:0] packet_flat;  // Flattened packet_data (1518*8=12144 bits)
    wire packet_valid;
    wire [639:0] features_flat;  // Flattened features (20*32=640 bits)
    wire [7:0] class_label;
    wire anomaly_flag;
    // Ethernet MAC
    eth_mac_1g mac (
        .clk(clk_125mhz),
        .rst(rst),
        .rx_data(gmii_rxd),
        .rx_dv(gmii_rx_dv),
        .rx_er(gmii_rx_er),
        .tx_data(gmii_txd),
        .tx_en(gmii_tx_en),
        .tx_er(gmii_tx_er),
        .packet_flat(packet_flat),
        .packet_valid(packet_valid)
    );
    // Packet parser
    packet_parser parser (
        .clk(clk_125mhz),
        .rst(rst),
        .packet_in_flat(packet_flat),
        .valid_in(packet_valid),
        .features_flat(features_flat)
    );
    // CNN classifier with learning
    cnn_classifier_learn classifier (
        .clk(clk_125mhz),
        .rst(rst),
        .features_in_flat(features_flat),
        .label_in(label_in),
        .label_in_valid(label_in_valid),
        .anomaly_flag(anomaly_flag),
        .class_label(class_label)
    );
    // Anomaly autoencoder with learning
    anomaly_autoencoder_learn anomaly (
        .clk(clk_125mhz),
        .rst(rst),
        .features_in_flat(features_flat),
        .anomaly_flag(anomaly_flag)
    );
    // UART
    uart_rs232 uart (
        .clk(clk_125mhz),
        .rst(rst),
        .tx_data(alert_out), // Send alert byte
        .tx_valid(alert_out != 8'h00), // Send when alert
        .tx_ready(), // Not used
        .rx_data(label_in),
        .rx_valid(label_in_valid),
        .rx_ready(1'b1), // Always ready
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );
    // Alert logic
    always @(posedge clk_125mhz) begin
        if (rst) alert_out <= 8'h00;
        else alert_out <= (anomaly_flag || class_label != 0) ? 8'hFF : 8'h00;
    end
endmodule