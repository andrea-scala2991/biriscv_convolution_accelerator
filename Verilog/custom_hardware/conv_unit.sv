`timescale 1ns / 1ps


module conv_unit(
     input logic clk_i
    ,input logic rst_i

    //INPUTS
    ,input logic  [ 31:0]  opcode_opcode_i
    ,input logic  [ 31:0]  opcode_pc_i
    ,input logic           opcode_invalid_i
    ,input logic  [  4:0]  opcode_rd_idx_i
    ,input logic  [  4:0]  opcode_ra_idx_i
    ,input logic  [  4:0]  opcode_rb_idx_i
    ,input logic  [ 31:0]  opcode_ra_operand_i
    ,input logic  [ 31:0]  opcode_rb_operand_i
    
    //OUTPUTS
    ,output logic           busy_o
    ,output logic           valid_o
    ,output logic [31:0]    writeback_o
    );
endmodule
