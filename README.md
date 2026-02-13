# FpgaAIAcelerator
AI accelerator for a network intrusion detection system (NIDS) based on Virtex-6
### A ready-to-use ML605 board project implementing. 
The project includes:
Hardware: Verilog code for the accelerator (nids_autonomous) with feature extraction, CNN classifier, anomaly autoencoder and online learning.
Testbench: A complete simulation testbench for verification.

Xilinx ISE 14.7 is a legacy integrated development environment (IDE) for FPGA design, released in 2013, supporting Verilog-2001 and targeting devices like Virtex-6 (used in ML605 board). This guide covers **every step** to set up, run, and analyze the testbenches (TBs) you have for the NIDS project modules: `tb_nids_autonomous`, `tb_cnn_classifier_learn`, `tb_eth_mac_1g`, `tb_packet_parser`, `tb_uart_rs232`, and `tb_anomaly_autoencoder_learn`. 

#### 1. Prerequisites
Before starting:
- **Hardware/Software Requirements**:
  - Windows 7/8/10 or Linux (ISE 14.7 is 32/64-bit compatible; last supported on Win10).
  - Xilinx ISE 14.7 installed (full version or WebPACK; download from AMD/Xilinx archive if needed—note: official support ended in 2018, but available via legacy downloads).
  - ML605 board (Virtex-6 LX240T) for hardware testing (optional for simulation; TBs are for ISim simulator).
  - USB-JTAG cable (Platform Cable USB II) for board programming (not needed for simulation).
  - GTKWave or ModelSim (optional for better waveform viewing; ISim is built-in).
- **Files Needed**:
  - All .v modules: `nids_autonomous.v`, `eth_mac_1g.v`, `packet_parser.v`, `cnn_classifier_learn.v`, `anomaly_autoencoder_learn.v`, `uart_rs232.v`.
  - All TBs: `tb_nids_autonomous.v`, `tb_cnn_classifier_learn.v`, `tb_eth_mac_1g.v`, `tb_packet_parser.v`, `tb_uart_rs232.v`, `tb_anomaly_autoencoder_learn.v`.
  - UCF file: `ml605.ucf` (for pin constraints, if synthesizing for board).
- **Knowledge Assumptions**: Basic Verilog, FPGA flow (synthesis, simulation). If new, refer to Xilinx UG626 (ISim User Guide).
- **Backup**: Copy all files to a new folder (e.g., `C:\ISE_Projects\NIDS_TB`).

If ISE is not installed, download from AMD (requires account and license).  
#### 2. Setting Up the Project in Xilinx ISE 14.7
1. **Launch ISE**:
   - Open "ISE Design Suite 14.7" from Start Menu.
   - Select "Create New Project" in Project Navigator.
2. **Create Project**:
   - Name: `NIDS_Testbenches`.
   - Location: Choose folder (e.g., `C:\ISE_Projects\NIDS_TB`).
   - Top-Level Source Type: HDL.
   - Family: Virtex6.
   - Device: XC6VLX240T.
   - Package: FF1156.
   - Speed: -1 (default for ML605).
   - Preferred Language: Verilog.
   - Click "Next" > "Finish".
3. **Add Source Files**:
   - Right-click "Hierarchy" pane > "Add Source".
   - Add all .v modules and TBs (multi-select).
   - For each TB, set as "Simulation" source (right-click > "Source Properties" > "Source Type: Verilog Test Fixture").
4. **Add UCF (if needed)**:
   - Right-click > "Add Copy of Source" > Add `ml605.ucf` (for synthesis, not simulation).
5. **Project Settings**:
   - Project > Design Properties:
     - Simulator: ISim (VHDL/Verilog).
     - Enable Message Filtering: On (to reduce warnings).
   - Simulation Properties: Set "Simulation Run Time" to 1000ns (or longer for UART tests).
6. **Verify Setup**:
   - Expand Hierarchy: See modules and TBs.
   - Check for errors in Console (bottom pane).  
Screenshot of creating new project in ISE 14.7.

#### 3. Running Simulations for Each Testbench
In ISE, simulations use ISim. For each TB:
- Select TB in Hierarchy (e.g., `tb_nids_autonomous`).
- Process > Simulate Behavioral Model (or right-click TB > "Simulate Behavioral Model").
- ISim launches: Set run time (e.g., 1000ns), click "Run for the time specified".
- View Console for $display outputs.
- Add signals to Waveform: In ISim, drag from "Name" pane to waveform window.
- Rerun: "Rerun All" button.

**Common Simulation Settings**:
- In ISim: Tools > Options > Default Waveform Viewer: ISim.
- For long runs (UART): Increase run time to 1ms+.
- Dump VCD: Already in TBs ($dumpfile, $dumpvars) — open in GTKWave after simulation.

Now, detailed steps for each TB.
##### 3.1. tb_nids_autonomous.v (Top-Level Integration)
- **Purpose**: Tests full chain: Ethernet RX → Parser → CNN/Autoencoder → UART/Alert.
- **Steps**:
  1. Select `tb_nids_autonomous.v` in Hierarchy.
  2. Run simulation (Process > Simulate Behavioral Model).
  3. In ISim Console: Observe $display for each test (e.g., "Test 1: Normal IP/TCP packet", class_label, alert_out).
  4. Waveform: Add `dut.packet_flat`, `dut.features_flat`, `dut.anomaly_flag`, `dut.class_label`, `dut.uart_tx_pin`.
  5. Verify: For Test 1, anomaly_flag=0 if MSE low; alert_out=FF if anomaly or class !=0.
  6. Run time: 1000ns (covers multiple packets).
- **Expected Output**: Console logs for 7 tests; anomaly in Test 3/7.
- **Debug**: If no packet_valid — check RX logic.

##### 3.2. tb_cnn_classifier_learn.v (CNN Module)
- **Purpose**: Tests classification and training (weight updates on label/anomaly).
- **Steps**:
  1. Select `tb_cnn_classifier_learn.v`.
  2. Run simulation.
  3. Console: $display for class_label after each input; weight changes after update_en.
  4. Waveform: Add `dut.hidden[0]`, `dut.logits[0]`, `dut.fc1_weights[0][0]` (before/after update).
  5. Verify: Test 2/3 — weights increment on update_en; class_label changes with input.
  6. Run time: 500ns.
- **Expected Output**: Weights change from initial (e.g., random) to +1 after anomaly.

##### 3.3. tb_eth_mac_1g.v (Ethernet MAC)
- **Purpose**: Tests RX flattening, TX echo, packet_valid.
- **Steps**:
  1. Select `tb_eth_mac_1g.v`.
  2. Run simulation.
  3. Console: $display for packet_valid, flat sample.
  4. Waveform: Add `dut.rx_buffer[0]`, `packet_flat[0 +: 8]`, `tx_data` (should echo rx_data).
  5. Verify: Test 1 — packet_flat matches sent data; valid pulses after packet.
  6. Run time: 200ns.
- **Expected Output**: packet_valid=1 after full packet; tx_er=1 in Test 4.

##### 3.4. tb_packet_parser.v (Packet Parser)
- **Purpose**: Tests parsing, features flattening.
- **Steps**:
  1. Select `tb_packet_parser.v`.
  2. Run simulation.
  3. Console: $display for features_flat samples (e.g., src_port in Test 2).
  4. Waveform: Add `dut.features[0]`, `features_flat[0 +: 32]`.
  5. Verify: Test 1 — features[2]=src_port for TCP; Test 3 — features[0]=0 for non-IP.
  6. Run time: 500ns.
- **Expected Output**: Eth type in features[18] matches set.

##### 3.5. tb_uart_rs232.v (UART)
- **Purpose**: Tests TX/RX, FIFO, bit timing.
- **Steps**:
  1. Select `tb_uart_rs232.v`.
  2. Run simulation (long run time for baud).
  3. Console: $display for TX ready, RX data/valid.
  4. Waveform: Zoom to tx_pin/rx_pin for bit sequence (start=0, data, stop=1).
  5. Verify: Test 1 — TX pin sequence for 0xA5: start(0), bits(1,0,1,0,0,1,0,1), stop(1).
  6. Run time: 1ms (for multiple bytes).
- **Expected Output**: RX valid=1 after byte; FIFO full=0 after 16 bytes.

##### 3.6. tb_anomaly_autoencoder_learn.v (Autoencoder)
- **Purpose**: Tests encoding/decoding, MSE, anomaly_flag, training.
- **Steps**:
  1. Select `tb_anomaly_autoencoder_learn.v`.
  2. Run simulation.
  3. Console: $display for anomaly_flag, weight/bias after update.
  4. Waveform: Add `dut.err[0]`, `dut.mse`, `dut.enc_weights[0][0]`.
  5. Verify: Test 2 — anomaly_flag=1 on high values; weights change after.
  6. Run time: 1000ns.
- **Expected Output**: Anomaly in Test 2/4; no anomaly in Test 1/6.

#### 4. Viewing and Analyzing Results
- **ISim Waveform**:
  - In ISim: View > Add to Waveform > Select signals (e.g., anomaly_flag, class_label).
  - Zoom/Measure: Use cursors for timing (e.g., latency from valid_in to anomaly_flag ~ few clocks).
  - Groups: Group related signals (e.g., "Features" for feat_in[0:19]).
- **GTKWave** (Better for Large VCD):
  - After simulation: Open .vcd in GTKWave.
  - Add signals, use "Append" for hierarchy.
  - Search: For "anomaly_flag" rising edge.
- **Console Logs**: All TBs use $display for key results (e.g., "Anomaly detected").
- **VCD Export**: Already in each TB — analyze offline.  
ISim waveform viewer screenshot.

#### 5. Debugging Tips
- **Common Errors**:
  - "Declarations not allowed": Ensure no `integer` inside always/if — all outside.
  - "Cannot access memory directly": Use procedural blocks for memory write/read.
  - Synthesis warnings: Ignore behavioral for simulation; fix for hardware.
- **Slow Simulation**: Reduce run time or use -nogui in ISim.
- **Waveform Overload**: Limit dumped vars with $dumpvars(1, dut) for submodule.
- **UART Timing**: If baud mismatch — adjust BAUD_PERIOD (CLK_FREQ / BAUD_RATE).
- **Resource Check**: Synthesize top (nids_autonomous) — check LUT/FF usage (~30–50% on Virtex-6 LX240T).
- **Hardware Test**: Generate bitstream > Program ML605 > Use ChipScope for real signals.

#### 6. Advanced Usage
- **Batch Simulation**: Use Tcl script in ISE: `isim.cmd` with "run all" for all TBs.
- **Code Coverage**: Enable in ISim Properties > "Generate Coverage" — check uncovered lines.
- **Parameterization**: Change HIDDEN_SIZE in params for sensitivity analysis.
- **Integration Test**: Combine all TBs in one super-TB if needed.
- **Update TBs**: Add assertions (e.g., `assert(packet_valid == 1)`) for auto-check.

© 2026 Trusted Systems
