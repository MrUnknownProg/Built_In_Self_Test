//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Thu Oct  8 08:56:51 2026
//Host        : HP15S running 64-bit major release  (build 9200)
//Command     : generate_target design_2.bd
//Design      : design_2
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "design_2,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=design_2,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=11,numReposBlks=11,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=9,numPkgbdBlks=0,bdsource=USER,synth_mode=None}" *) (* HW_HANDOFF = "design_2.hwdef" *) 
module design_2
   (clk_i_0,
    done_o_0,
    fail_count_o_0,
    fail_flag_o_0,
    fault_addr_o,
    fault_addr_valid_o,
    fault_hit_o_0,
    fault_switch_i_0,
    repair_count_o_0,
    repair_full_o_0,
    repair_reset_i_0,
    repaired_logical_addr_o_0,
    repaired_physical_addr_o_0,
    repaired_valid_o_0,
    rst_i_0,
    start_i_0,
    valid_o_0);
  input clk_i_0;
  output done_o_0;
  output [7:0]fail_count_o_0;
  output fail_flag_o_0;
  output [9:0]fault_addr_o;
  output fault_addr_valid_o;
  output fault_hit_o_0;
  input [7:0]fault_switch_i_0;
  output [9:0]repair_count_o_0;
  output repair_full_o_0;
  input repair_reset_i_0;
  output [9:0]repaired_logical_addr_o_0;
  output [9:0]repaired_physical_addr_o_0;
  output repaired_valid_o_0;
  input rst_i_0;
  input start_i_0;
  output valid_o_0;

  wire addr_gen_0_addr_done_o;
  wire [9:0]addr_gen_0_addr_o;
  wire [9:0]address_remapper_0_physical_addr_o;
  wire [31:0]blk_mem_gen_0_doutb;
  wire clk_i_0;
  wire [2:0]comparator_0_fault_id_o;
  wire control_logic_0_addr_dir_o;
  wire control_logic_0_addr_en_o;
  wire control_logic_0_addr_rst_o;
  wire control_logic_0_compare_en_o;
  wire control_logic_0_fault_generate_o;
  wire [1:0]control_logic_0_pattern_sel_o;
  wire control_logic_0_we_o;
  wire [31:0]data_gen_0_data_o;
  wire done_o_0;
  wire [7:0]fail_count_o_0;
  wire fail_flag_o_0;
  wire [63:0]fault_addr_lfsr_0_fault_addr_o;
  wire [9:0]fault_addr_o;
  wire fault_addr_valid_o;
  wire fault_hit_o_0;
  wire [31:0]fault_inject_0_data_o;
  wire [2:0]fault_inject_0_fault_id_o;
  wire [7:0]fault_order_capture_0_active_faults_o;
  wire [3:0]fault_order_capture_0_fault_order_count_o;
  wire [23:0]fault_order_capture_0_fault_order_o;
  wire [7:0]fault_switch_i_0;
  wire [9:0]repair_controller_0_lookup_phys_addr_o;
  wire repair_controller_0_lookup_valid_o;
  wire [9:0]repair_count_o_0;
  wire repair_full_o_0;
  wire repair_reset_i_0;
  wire [9:0]repaired_logical_addr_o_0;
  wire [9:0]repaired_physical_addr_o_0;
  wire repaired_valid_o_0;
  wire rst_i_0;
  wire start_i_0;
  wire valid_o_0;
  wire [0:0]xlconstant_0_dout;

  design_2_addr_gen_0_0 addr_gen_0
       (.addr_dir_i(control_logic_0_addr_dir_o),
        .addr_done_o(addr_gen_0_addr_done_o),
        .addr_en_i(control_logic_0_addr_en_o),
        .addr_o(addr_gen_0_addr_o),
        .addr_rst_i(control_logic_0_addr_rst_o),
        .clk_i(clk_i_0),
        .rst_i(rst_i_0));
  design_2_address_remapper_0_1 address_remapper_0
       (.logical_addr_i(addr_gen_0_addr_o),
        .physical_addr_o(address_remapper_0_physical_addr_o),
        .repair_addr_i(repair_controller_0_lookup_phys_addr_o),
        .repair_valid_i(repair_controller_0_lookup_valid_o));
  design_2_blk_mem_gen_0_0 blk_mem_gen_0
       (.addra(address_remapper_0_physical_addr_o),
        .addrb(address_remapper_0_physical_addr_o),
        .clka(clk_i_0),
        .clkb(clk_i_0),
        .dina(data_gen_0_data_o),
        .doutb(blk_mem_gen_0_doutb),
        .ena(xlconstant_0_dout),
        .enb(xlconstant_0_dout),
        .wea(control_logic_0_we_o));
  design_2_comparator_0_0 comparator_0
       (.addr_i(addr_gen_0_addr_o),
        .clk_i(clk_i_0),
        .compare_en_i(control_logic_0_compare_en_o),
        .expected_data_i(data_gen_0_data_o),
        .fail_count_o(fail_count_o_0),
        .fail_flag_o(fail_flag_o_0),
        .fault_addr_o(fault_addr_o),
        .fault_addr_valid_o(fault_addr_valid_o),
        .fault_id_i(fault_inject_0_fault_id_o),
        .fault_id_o(comparator_0_fault_id_o),
        .read_data_i(fault_inject_0_data_o),
        .rst_i(rst_i_0));
  design_2_control_logic_0_0 control_logic_0
       (.addr_dir_o(control_logic_0_addr_dir_o),
        .addr_done_i(addr_gen_0_addr_done_o),
        .addr_en_o(control_logic_0_addr_en_o),
        .addr_rst_o(control_logic_0_addr_rst_o),
        .clk_i(clk_i_0),
        .compare_en_o(control_logic_0_compare_en_o),
        .done_o(done_o_0),
        .fault_addr_valid_i(valid_o_0),
        .fault_generate_o(control_logic_0_fault_generate_o),
        .pattern_sel_o(control_logic_0_pattern_sel_o),
        .rst_i(rst_i_0),
        .start_i(start_i_0),
        .we_o(control_logic_0_we_o));
  design_2_data_gen_0_0 data_gen_0
       (.data_o(data_gen_0_data_o),
        .pattern_sel_i(control_logic_0_pattern_sel_o));
  design_2_fault_addr_lfsr_0_0 fault_addr_lfsr_0
       (.clk_i(clk_i_0),
        .fault_addr_o(fault_addr_lfsr_0_fault_addr_o),
        .generate_i(control_logic_0_fault_generate_o),
        .rst_i(rst_i_0),
        .valid_o(valid_o_0));
  design_2_fault_inject_0_0 fault_inject_0
       (.addr_i(address_remapper_0_physical_addr_o),
        .data_i(blk_mem_gen_0_doutb),
        .data_o(fault_inject_0_data_o),
        .fault_addr_i(fault_addr_lfsr_0_fault_addr_o),
        .fault_en_i(fault_order_capture_0_active_faults_o),
        .fault_hit_o(fault_hit_o_0),
        .fault_id_o(fault_inject_0_fault_id_o));
  design_2_fault_order_capture_0_0 fault_order_capture_0
       (.active_faults_o(fault_order_capture_0_active_faults_o),
        .clk_i(clk_i_0),
        .fault_order_count_o(fault_order_capture_0_fault_order_count_o),
        .fault_order_o(fault_order_capture_0_fault_order_o),
        .fault_switch_i(fault_switch_i_0),
        .repair_reset_i(repair_reset_i_0),
        .rst_i(rst_i_0));
  design_2_repair_controller_0_0 repair_controller_0
       (.clk_i(clk_i_0),
        .fault_addr_i(fault_addr_o),
        .fault_id_i(comparator_0_fault_id_o),
        .fault_order_count_i(fault_order_capture_0_fault_order_count_o),
        .fault_order_i(fault_order_capture_0_fault_order_o),
        .fault_valid_i(fault_addr_valid_o),
        .lookup_addr_i(addr_gen_0_addr_o),
        .lookup_phys_addr_o(repair_controller_0_lookup_phys_addr_o),
        .lookup_valid_o(repair_controller_0_lookup_valid_o),
        .mbist_done_i(done_o_0),
        .repair_count_o(repair_count_o_0),
        .repair_full_o(repair_full_o_0),
        .repair_reset_i(repair_reset_i_0),
        .repaired_logical_addr_o(repaired_logical_addr_o_0),
        .repaired_physical_addr_o(repaired_physical_addr_o_0),
        .repaired_valid_o(repaired_valid_o_0),
        .rst_i(rst_i_0));
  design_2_xlconstant_0_0 xlconstant_0
       (.dout(xlconstant_0_dout));
endmodule
