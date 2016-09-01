module yuv422to444_tb;

    logic clk, rst;
    
    nasti_stream_channel #(.DATA_WIDTH(64)) src();
    nasti_stream_channel #(.DATA_WIDTH(64)) dst();
    
    yuv422to444_noninterp yuv422to444 (
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

        #11;
        #2 dst.t_ready = 1;
        
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; 
        src.t_data[0][ 7: 0] = 8'd1; // y0
        src.t_data[0][15: 8] = 8'd2; // u
        src.t_data[0][23:16] = 8'd3; // y1
        src.t_data[0][31:24] = 8'd4; // v

        src.t_data[0][39:32] = 8'd5; // y0
        src.t_data[0][47:40] = 8'd6; // u
        src.t_data[0][55:48] = 8'd7; // y1
        src.t_data[0][63:56] = 8'd8; // v
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 1;                
                                
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 2;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 3;

        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 4;
        
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 5;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 6;
                               
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 7;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 8;

        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 9;

        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 10;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 11;                
                                
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 12;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 13;

        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 14;
        
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 15;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 16;
                             
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 17;
                    
        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 18;

        #2 wait(src.t_ready);
        #2 src.t_valid = 1; src.t_data = 19; src.t_last = 1;
    end
 
    
endmodule
