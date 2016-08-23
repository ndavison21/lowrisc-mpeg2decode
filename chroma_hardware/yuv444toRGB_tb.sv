module yuv444toRGB_tb;

   logic clk, rst;
   integer i;


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
   logic br_en, br_clk, br_rst;
   logic [7:0]  br_we;
   logic [63:0] br_addr, br_wrdata, br_rddata;

   nasti_channel # (
      .DATA_WIDTH(64)
   ) in_ch();

   nasti_stream_channel # (
      .DATA_WIDTH(64)
   ) chroma_in_ch();
   nasti_stream_channel # (
      .DATA_WIDTH(64)
   ) out_ch();

   
   nasti_stream_mover # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(64),
      .MAX_BURST_LENGTH(8)
   ) dm_data_to_local (
      .aclk(clk),
      .aresetn(aresetn),
      .src(in_ch),
      .dest(chroma_in_ch),
      .r_src(r_src),
      .r_len(r_len),
      .r_valid(r_valid),
      .r_ready(r_ready)
   );
   
   stream_nasti_mover# (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(64),
      .MAX_BURST_LENGTH(6)
   ) dm_data_from_local (
      .aclk(clk),
      .aresetn(aresetn),
      .src(out_ch),
      .dest(in_ch),
      .r_dest(r_dest),
      .r_valid(r_valid_out),
      .r_ready(r_ready_out)
   );
   
   nasti_bram_ctrl # (
      .ADDR_WIDTH(64),
      .DATA_WIDTH(64),
      .BRAM_ADDR_WIDTH(64)
   ) tb_bram_ctrl(
       .s_nasti_aclk(clk),
       .s_nasti_aresetn(aresetn),
       .s_nasti(in_ch),
    
       .bram_clk(br_clk),
       .bram_rst(br_rst),
       .bram_en(br_en),
       .bram_we(br_we),
       .bram_addr(br_addr),
       .bram_wrdata(br_wrdata),
       .bram_rddata(br_rddata)
   );
   
   logic [63:0] read_memory  [0:15];
   logic [63:0] write_memory [0:15];
   
   always_ff @(posedge clk or posedge rst)
   begin
       if (rst) begin
          read_memory[0]  <= 1 + (2<<8) + ( 4<<16) + ( 8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[1]  <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[2]  <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[3]  <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[4]  <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[5]  <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[6]  <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[7]  <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[8]  <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[9]  <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[10] <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[11] <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[12] <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[13] <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
          read_memory[14] <= 1 + (2<<8) + (4<<16) + (8<<24) + (16<<32) + (32<<40) + (64<<48) + (128<<54);
          read_memory[15] <= 3 + (6<<8) + (12<<16) + (24<<24) + (48<<32) + (96<<40) + (192<<48) + (129<<54);
       end else
       begin
          if (br_en)
          begin
             $display("MEM_READ: Y0: %d, U: %d, Y1: %d, V: %d, Y0: %d, U: %d, Y1: %d, V: %d", 
                br_rddata[ 7: 0], 
                br_rddata[15: 8], 
                br_rddata[23:16], 
                br_rddata[31:24],
                br_rddata[39:32], 
                br_rddata[47:40], 
                br_rddata[55:48], 
                br_rddata[63:56]);
             br_rddata <= read_memory[br_addr>>3];
          end
          
          if (&br_we)
          begin
             write_memory[br_addr>>3] <= br_wrdata;
             $display("MEM_WRITE: v: %d, u: %d, y0: %d, 0: %d, v: %d, u: %d, y1: %d, 0: %d", 
                br_wrdata[ 7: 0], 
                br_wrdata[15: 8],
                br_wrdata[23:16], 
                br_wrdata[31:24],
                br_wrdata[39:32], 
                br_wrdata[47:40], 
                br_wrdata[55:48], 
                br_wrdata[63:56]);
          end
       end
   end

   yuv444toRGB yuv444toRGB(
      .clk(clk),
      .rst(aresetn),
      .src(chroma_in_ch),
      .dst(out_ch)
   );
   initial begin
      #3;
      wait(!rst);
      #2.5;
      #20;
      r_valid = 1;
      r_valid_out = 1;
      r_src   = 0;
      r_dest  = 8;
      r_len   = 128;
      #20;
      r_valid = 0;
   end

endmodule