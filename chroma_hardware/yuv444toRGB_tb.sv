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
          read_memory[0]  <= 64'h8fdb4ad5d652c633;
          read_memory[1]  <= 64'h6cab66d9bffe01bd;
          read_memory[2]  <= 64'he7858fc0ff08f21f;
          read_memory[3]  <= 64'h33cac1fba5688d7a;
          read_memory[4]  <= 64'h66a3d75871929692;
          read_memory[5]  <= 64'h576de545cee7321e;
          read_memory[6]  <= 64'h0d3eae1011fa7a43;
          read_memory[7]  <= 64'hb02cb0c0a6ff6c33;
          read_memory[8]  <= 64'h439141237a7c2f28;
          read_memory[9]  <= 64'hb00d91fdc3c25ec8;
          read_memory[10] <= 64'h0f57955cc4f8a73b;
          read_memory[11] <= 64'h86d3d93320bc2414;
          read_memory[12] <= 64'hbdce6f1287b9400b;
          read_memory[13] <= 64'h512d2242ce2023a6;
          read_memory[14] <= 64'h5aa30eaa5c1ea929;
          read_memory[15] <= 64'h564ff1558d3c6544;
       end else
       begin
          if (br_en)
          begin
             $display("MEM_READ: V: %d, U: %d, Y0: %d, 0: %d, V: %d, U: %d, Y1: %d, 0: %d", 
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
             $display("MEM_WRITE: b: %d, g: %d, r: %d, 0: %d, b: %d, g: %d, r: %d, 0: %d", 
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
      .aclk(clk),
      .aresetn(aresetn),
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