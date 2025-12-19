module conv_unit #
(
 parameter MAX_K = 9, // kernel side length
 parameter MAX_K_ELEMS = MAX_K*MAX_K, // max elements = 81
 parameter MAX_INPUT_W = 4096 )
 
 (
  input logic clk_i,
  input logic rst_i,
  
  // Issued instruction
  input logic opcode_valid_i,
  input logic [31:0] opcode_opcode_i, 
  input logic opcode_invalid_i, 
  input logic [31:0] opcode_ra_operand_i, 
  input logic [31:0] opcode_rb_operand_i,
  
  // LSU interface 
  output logic mem_rd_o, 
  output logic [31:0] mem_addr_o, 
  input logic mem_ack_i, 
  input logic [31:0] mem_data_i, 
  
  // Writeback 
  output logic busy_o, 
  output logic valid_o, 
  output logic [31:0] writeback_o );
  
  /* ---------------- Decode ---------------- */
  localparam OPC_CUSTOM0 = 7'b0001011; 
  
  wire is_custom = opcode_valid_i && !opcode_invalid_i && opcode_opcode_i[6:0] == OPC_CUSTOM0;
  wire [2:0] funct3 = opcode_opcode_i[14:12]; 
  
  localparam F3_SETBASE = 3'b000; 
  localparam F3_SETSIZE = 3'b001; 
  localparam F3_RUN = 3'b010; 
  
  /* ---------------- State machine ---------------- */
  typedef enum logic [2:0] { 
    IDLE,
    LOAD_KERNEL, 
    LOAD_INPUT, 
    COMPUTE, 
    NEXT_WINDOW, 
    DONE }
    state_t;
    state_t state_q, state_d; 
    
    /* ---------------- Configuration ---------------- */
    logic [31:0] kernel_base_q, input_base_q;
    logic [3:0] kernel_dim_q; // kernel side length 1..9
    logic [6:0] kernel_elems_q; // derived N*N (<=81) 
    logic [11:0] input_words_q; 
    
    /* derive kernel elements */ 
    always_comb 
    begin
        kernel_elems_q = kernel_dim_q * kernel_dim_q;
    end 
    
    /* ---------------- Local storage ---------------- */
    logic [31:0] kernel_mem [0:MAX_K_ELEMS-1]; 
    logic [31:0] input_mem [0:MAX_INPUT_W-1];
    
    /* ---------------- LSU indices ---------------- */
    logic [11:0] rd_idx_q, rd_idx_d; 
    logic [11:0] wr_idx_q, wr_idx_d; 
    logic [11:0] window_q, window_d; 
    
    /* ---------------- Output buffer ---------------- */ 
    logic out_valid_q, out_valid_d; 
    logic [31:0] out_data_q, out_data_d;
    
    /* ---------------- MAC ---------------- */ 
    integer i; 
    logic [63:0] sum; 
    
    always_comb 
    begin
        sum = 64'd0;
        for (i = 0; i < MAX_K_ELEMS; i++)
            if (i < kernel_elems_q && (window_q + i) < input_words_q) 
                sum += kernel_mem[i] * input_mem[window_q + i];
    end 
    
    /* ---------------- FSM ---------------- */ 
    
    always_comb 
    begin 
        state_d = state_q;
        rd_idx_d = rd_idx_q; 
        wr_idx_d = wr_idx_q; 
        window_d = window_q; 
        mem_rd_o = 1'b0; 
        mem_addr_o = 32'b0; 
        busy_o = 1'b1; 
        out_valid_d = out_valid_q; 
        out_data_d = out_data_q;
        
        case (state_q)
            IDLE: begin 
                busy_o = 1'b0;
                rd_idx_d = 0; 
                wr_idx_d = 0; 
                window_d = 0; 
                
                if (is_custom && funct3 == F3_RUN && kernel_elems_q != 0 && input_words_q != 0)
                    state_d = LOAD_KERNEL; 
            end 
            
            /* -------- Kernel load -------- */ 
            LOAD_KERNEL: begin 
                if (rd_idx_q < kernel_elems_q) begin 
                    mem_rd_o = 1'b1; 
                    mem_addr_o = kernel_base_q + (rd_idx_q << 2); 
                    rd_idx_d = rd_idx_q + 1; 
                end 
                
                if (mem_ack_i) begin 
                    kernel_mem[wr_idx_q] = mem_data_i; 
                    wr_idx_d = wr_idx_q + 1; 
                    
                    if (wr_idx_q + 1 == kernel_elems_q) begin 
                        rd_idx_d = 0; 
                        wr_idx_d = 0; 
                        state_d = LOAD_INPUT;
                     end 
                 end 
             end 
             
             /* -------- Input load -------- */
            LOAD_INPUT: begin 
                if (rd_idx_q < input_words_q) begin 
                    mem_rd_o = 1'b1; 
                    mem_addr_o = input_base_q + (rd_idx_q << 2);
                    rd_idx_d = rd_idx_q + 1; 
                end 
                
                if (mem_ack_i) begin 
                    input_mem[wr_idx_q] = mem_data_i; 
                    wr_idx_d = wr_idx_q + 1; 
                    
                    if (wr_idx_q + 1 == input_words_q) begin 
                        rd_idx_d = 0; 
                        wr_idx_d = 0; 
                        
                        state_d = COMPUTE;
                    end 
                end 
            end
            
            /* -------- Compute -------- */ 
            COMPUTE: begin 
                if (!out_valid_q) begin 
                    out_data_d = sum[31:0]; 
                    out_valid_d = 1'b1; 
                    state_d = NEXT_WINDOW; 
                end 
            end 
            
            NEXT_WINDOW: begin 
                if (!out_valid_q) begin 
                    if (window_q + kernel_elems_q < input_words_q) begin 
                        window_d = window_q + 1; 
                        state_d = COMPUTE; 
                    end else begin 
                        state_d = DONE; 
                    end 
                end 
            end 
            
            DONE: begin 
                if (!out_valid_q) 
                    state_d = IDLE; 
            end 
            endcase 
        end 
        
        /* ---------------- Sequential ---------------- */ 
        always_ff @(posedge clk_i or posedge rst_i) begin 
            if (rst_i) begin 
                state_q <= IDLE; 
                rd_idx_q <= 0; 
                wr_idx_q <= 0; 
                window_q <= 0; 
                kernel_base_q <= 0; 
                input_base_q <= 0; 
                kernel_dim_q <= 0; 
                input_words_q <= 0; 
                out_valid_q <= 0; 
                out_data_q <= 0; 
            end else begin 
                state_q <= state_d; 
                rd_idx_q <= rd_idx_d; 
                wr_idx_q <= wr_idx_d; 
                window_q <= window_d; 
                out_valid_q <= out_valid_d; 
                out_data_q <= out_data_d; 
                
                if (out_valid_q) 
                    out_valid_q <= 1'b0;
                
                if (is_custom && funct3 == F3_SETBASE) begin 
                    kernel_base_q <= opcode_ra_operand_i; 
                    input_base_q <= opcode_rb_operand_i; 
                end 
                
                if (is_custom && funct3 == F3_SETSIZE) begin 
                    kernel_dim_q <= opcode_ra_operand_i[3:0]; // 1..9 
                    input_words_q <= opcode_rb_operand_i[11:0]; 
                end 
            end 
        end 
        
        assign valid_o = out_valid_q;
        assign writeback_o = out_data_q;
endmodule
