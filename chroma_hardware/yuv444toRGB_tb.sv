module yuv444toRGB_tb;

    logic clk, rst;

    nasti_stream_channel #(.DATA_WIDTH(64)) src();
    nasti_stream_channel #(.DATA_WIDTH(64)) dst();
    
    yuv444toRGB yuv444toRGB (
        .clk(clk),
        .rst(rst),
        
        .src(src),
        .dst(dst)
    );

    initial begin
        clk = 0; rst = 1;
        #1 rst = 0; clk = 1;
        #1 rst = 1; clk = 0;
        forever #1 clk = !clk;
    end
    
    initial begin
        src.t_last = 0;
        src.t_keep = 8'hff;
        dst.t_ready = 1;
        src.t_valid = 0;

        #11;
        
        @(posedge clk);
        #0
        src.t_valid = 1; 
        src.t_data[0][ 7: 0] = 8'd1; // v
        src.t_data[0][15: 8] = 8'd2; // u
        src.t_data[0][23:16] = 8'd3; // y
        src.t_data[0][31:24] = 8'd0; // 0

        src.t_data[0][39:32] = 8'd4; // v
        src.t_data[0][47:40] = 8'd5; // u
        src.t_data[0][55:48] = 8'd6; // y
        src.t_data[0][63:56] = 8'd0; // 0

        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_data[0][ 7: 0] = 8'd7;  // v
        src.t_data[0][15: 8] = 8'd8;  // u
        src.t_data[0][23:16] = 8'd9; // y
        src.t_data[0][31:24] = 8'd0;  // 0

        src.t_data[0][39:32] = 8'd10; // v
        src.t_data[0][47:40] = 8'd11; // u
        src.t_data[0][55:48] = 8'd12; // y
        src.t_data[0][63:56] = 8'd0;  // 0             
                                
        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_data[0][ 7: 0] = 8'd13; // v
        src.t_data[0][15: 8] = 8'd14; // u
        src.t_data[0][23:16] = 8'd15; // y
        src.t_data[0][31:24] = 8'd0; // 0

        src.t_data[0][39:32] = 8'd16; // v
        src.t_data[0][47:40] = 8'd17; // u
        src.t_data[0][55:48] = 8'd18; // y
        src.t_data[0][63:56] = 8'd0; // 0
                    
        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_data[0][ 7: 0] = 8'd19;  // v
        src.t_data[0][15: 8] = 8'd20;  // u
        src.t_data[0][23:16] = 8'd21; // y
        src.t_data[0][31:24] = 8'd0;  // 0

        src.t_data[0][39:32] = 8'd22; // v
        src.t_data[0][47:40] = 8'd23; // u
        src.t_data[0][55:48] = 8'd24; // y
        src.t_data[0][63:56] = 8'd0;  // 0  


        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_data[0][ 7: 0] = 8'd25; // v
        src.t_data[0][15: 8] = 8'd26; // u
        src.t_data[0][23:16] = 8'd27; // y
        src.t_data[0][31:24] = 8'd0; // 0

        src.t_data[0][39:32] = 8'd28; // v
        src.t_data[0][47:40] = 8'd29; // u
        src.t_data[0][55:48] = 8'd30; // y
        src.t_data[0][63:56] = 8'd0; // 0
                    
        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_data[0][ 7: 0] = 8'd31;  // v
        src.t_data[0][15: 8] = 8'd32;  // u
        src.t_data[0][23:16] = 8'd33; // y
        src.t_data[0][31:24] = 8'd0;  // 0

        src.t_data[0][39:32] = 8'd34; // v
        src.t_data[0][47:40] = 8'd35; // u
        src.t_data[0][55:48] = 8'd36; // y
        src.t_data[0][63:56] = 8'd0;  // 0  

        wait (src.t_ready);
        @(posedge clk);
        #0
        src.t_last = 1;
        src.t_data[0][ 7: 0] = 8'd37;  // v
        src.t_data[0][15: 8] = 8'd38;  // u
        src.t_data[0][23:16] = 8'd39; // y
        src.t_data[0][31:24] = 8'd0;  // 0

        src.t_data[0][39:32] = 8'd40; // v
        src.t_data[0][47:40] = 8'd41; // u
        src.t_data[0][55:48] = 8'd42; // y
        src.t_data[0][63:56] = 8'd0;  // 0 

        wait(src.t_ready);
        @(posedge clk);
        #0
        src.t_last = 0;
        src.t_valid = 0;

        @(posedge clk);
        #0
        src.t_valid = 1;
        src.t_data[0][ 7: 0] = 8'd37;  // v
        src.t_data[0][15: 8] = 8'd38;  // u
        src.t_data[0][23:16] = 8'd39; // y
        src.t_data[0][31:24] = 8'd0;  // 0

        src.t_data[0][39:32] = 8'd40; // v
        src.t_data[0][47:40] = 8'd41; // u
        src.t_data[0][55:48] = 8'd42; // y
        src.t_data[0][63:56] = 8'd0;  // 0 

        wait(src.t_ready);
        @(posedge clk);
        #0
        src.t_valid = 0;
    end


endmodule