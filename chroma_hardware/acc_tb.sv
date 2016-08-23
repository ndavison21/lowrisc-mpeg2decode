module acc_tb;

   logic clk, rst;

   initial begin
      rst = 0;
      #3;
      rst = 1;
      #7;
      rst = 0;
   end

   initial begin
      clk = 0;
      forever clk = #2.5 !clk;
   end // initial begin

   assign aresetn = !rst;
   
   logic r_ready, r_valid, r_ready_out, r_valid_out;
   logic [63:0] r_src, r_len, r_dest;

   nasti_channel # (
      .DATA_WIDTH(64)
   ) tb_dma();
   nasti_channel # (
      .DATA_WIDTH(32)
   ) tb_inst_dma(), tb_internal();
   
   // Input rows controller and ROM
   logic br_en, br_clk, br_rst;
   logic [7:0]  br_we;
   logic [63:0] br_addr, br_wrdata, br_rddata;
   
   nasti_bram_ctrl # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(64),
      .BRAM_ADDR_WIDTH(64)
   ) tb_bram_ctrl(
       .s_nasti_aclk(clk),
       .s_nasti_aresetn(aresetn),
       .s_nasti(tb_dma),
    
       .bram_clk(br_clk),
       .bram_rst(br_rst),
       .bram_en(br_en),
       .bram_we(br_we),
       .bram_addr(br_addr),
       .bram_wrdata(br_wrdata),
       .bram_rddata(br_rddata)
   );
   
   logic [63:0] row  [0:15];
   logic [63:0] drow [0:15];
   
   always_ff @(posedge clk or posedge rst)
   begin
       if (rst) begin
          row[0]  <= 64'h8fdb4ad5d652c633;
          row[1]  <= 64'h6cab66d9bffe01bd;
          row[2]  <= 64'he7858fc0ff08f21f;
          row[3]  <= 64'h33cac1fba5688d7a;
          row[4]  <= 64'h66a3d75871929692;
          row[5]  <= 64'h576de545cee7321e;
          row[6]  <= 64'h0d3eae1011fa7a43;
          row[7]  <= 64'hb02cb0c0a6ff6c33;
          row[8]  <= 64'h439141237a7c2f28;
          row[9]  <= 64'hb00d91fdc3c25ec8;
          row[10] <= 64'h0f57955cc4f8a73b;
          row[11] <= 64'h86d3d93320bc2414;
          row[12] <= 64'hbdce6f1287b9400b;
          row[13] <= 64'h512d2242ce2023a6;
          row[14] <= 64'h5aa30eaa5c1ea929;
          row[15] <= 64'h564ff1558d3c6544;
       end else
       begin
          if (br_en)
          begin
             br_rddata <= row[br_addr>>3];
             if(!br_we)
             $display("MEM_READ: %x @ %x", 
                row[br_addr>>3],
                (br_addr>>3));
          end
          
          if (&br_we)
          begin
             drow[br_addr>>3] <= br_wrdata;
             $display("MEM_WRITE: %x @ %x", 
                br_wrdata,
                (br_addr>>3));
          end
       end
   end
   
   // Instruction controller and ROM
   logic lite_br_en, lite_br_clk, lite_br_rst;
   logic inst_valid, inst_ready;
   logic [11:0] inst_src, inst_dest, inst_len;
   logic [3:0]  lite_br_we;
   logic [31:0] lite_br_wrdata, lite_br_rddata;
   logic [11:0] lite_br_addr;
   logic [31:0] tb_insts [0:15];
   
   nasti_data_mover # (
      .ADDR_WIDTH(12),
      .DATA_WIDTH(32),
      .MAX_BURST_LENGTH(1)
   ) inst_mover (
      .aclk(clk),
      .aresetn(aresetn),
      .src(tb_internal),
      .dest(tb_inst_dma),
      .r_src(inst_src),
      .r_dest(inst_dest),
      .r_len(inst_len),
      .r_valid(inst_valid),
      .r_ready(inst_ready)
   );
   
   nasti_lite_bram_ctrl # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(32),
      .BRAM_ADDR_WIDTH(12)
   ) tb_inst_ctrl(
       .s_nasti_aclk(clk),
       .s_nasti_aresetn(aresetn),
       .s_nasti(tb_internal),
    
       .bram_clk(lite_br_clk),
       .bram_rst(lite_br_rst),
       .bram_en(lite_br_en),
       .bram_we(lite_br_we),
       .bram_addr(lite_br_addr),
       .bram_wrdata(lite_br_wrdata),
       .bram_rddata(lite_br_rddata)
   );
   
   always_ff @(posedge clk or posedge rst)
   begin
       if (rst) begin
          tb_insts[0] = 11 + (64'd2<<20);
       end else
       begin
          if (lite_br_en)
          begin
             lite_br_rddata <= tb_insts[lite_br_addr>>3];
          end
          
          if (&lite_br_we)
          begin
             tb_insts[lite_br_addr>>3] <= lite_br_wrdata;
             $display("MEM_WRITE: %x @ %x", 
                lite_br_wrdata, (lite_br_addr>>3));
          end
       end
   end

   video_acc acc(
      .aclk(clk),
      .aresetn(aresetn),
      .dma(tb_dma),
      
      .s_nasti_aclk(clk),
      .s_nasti_aresetn(aresetn),
      .s_nasti(tb_inst_dma)
   );

   initial begin
      #3;
      wait(!rst);
      #2.5;
      #5;
      inst_src   = 'd0;
      inst_dest  = 'd0;
      inst_len   = 'd8;
      inst_valid = 'd1;
      #5;
      inst_valid = 'd0;
   end

endmodule // acc_tb