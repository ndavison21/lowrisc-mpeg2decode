/* MUST INTERLEAVE YUV BEFORE SENDING TO THIS STREAM PROCESSOR
*  Expected 422 format is:
*  -------------------------------------
*  |   Y0   |   U    |   Y1   |   V    |
*  -------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
*  -------------------------------------
*
* Output format is 444:
*  -------------------------------------------------------------------------
*  |   U    |   Y0   |   V    | 0 Byte |   U    |   Y1   |   V    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
*/
module yuv422to444_noninterp (
    input clk, 
    input rst,

    nasti_stream_channel.slave src,
    nasti_stream_channel.master dst
    );

    logic        sent, t_last_latch;
    logic [63:0] data;
    logic [ 7:0] y0, y1, u, v;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            t_last_latch <= 0;
            src.t_ready  <= 1;
            dst.t_last   <= 0;
            sent         <= 0;
            dst.t_keep   <= 8'hff;
        end 
        else begin
            if (src.t_last) begin
                t_last_latch <= 1;
            end else if (t_last_latch && dst.t_last) begin
                t_last_latch <= 0;
            end

            if (!dst.t_ready) begin
                src.t_ready <= 0;
                sent <= 0;
            end
            else if (src.t_valid && !sent && dst.t_ready) begin
                if (&(src.t_keep[3:0])) begin
                    dst.t_data[ 7: 0] <= src.t_data[15: 8]; // u  <= src.t_data[15:8];
                    dst.t_data[15: 8] <= src.t_data[ 6: 0]; // y0 <= src.t_data[ 6:0];
                    dst.t_data[23:16] <= src.t_data[31:24]; // v  <= src.t_data[32:24];
                    dst.t_data[31:24] <= 8'b0;
                    
                    dst.t_data[39:32] <= src.t_data[15: 8]; // u  <= src.t_data[15:8];
                    dst.t_data[47:40] <= src.t_data[23:16]; // y1 <= src.t_data[23:16];
                    dst.t_data[53:48] <= src.t_data[31:24]; // v  <= src.t_data[32:24];
                    dst.t_data[61:54] <= 8'b0;
                end
                if (&(src.t_keep[7:4])) begin
                    sent <= 1;
                    src.t_ready <= 0;
                    y0 <= src.t_data[ 7:0];
                    u  <= src.t_data[15:8];
                    y1 <= src.t_data[23:16];
                    v  <= src.t_data[32:24];
                end
            end
            else if (sent) begin
                src.t_ready <= 1;
                sent <= 0;

                dst.t_data[ 7: 0] <= u;
                dst.t_data[15: 8] <= y0;
                dst.t_data[23:16] <= v;
                dst.t_data[31:24] <= 8'b0;
                
                dst.t_data[39:32] <= u;
                dst.t_data[47:40] <= y1;
                dst.t_data[53:48] <= v;
                dst.t_data[61:54] <= 8'b0;

                if (t_last_latch) begin
                    dst.t_last <= 1;
                end
            end
        end
    end
endmodule


/*
* Input is 444:
*  -------------------------------------------------------------------------
*  |   U    |   Y0   |   V    | 0 Byte |   U    |   Y1   |   V    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
*  Conversion taken from wikipedia: https://en.wikipedia.org/wiki/YUV#Y.E2.80.B2UV444_to_RGB888_conversion
*
*/
module yuv444toRGB (
    input clk,
    input rst,

    nasti_stream_channel.slave src,
    nasti_stream_channel.master dst
    );

    logic [7:0] y_0,u_0,v_0,y_1,u_1,v_1;
    logic [7:0] r_0,g_0,b_0,r_1,g_1,b_1;


    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            src.t_ready <= 1;
            dst.t_last <= 1;
        end else begin
            if (src.t_valid && &(src.t_keep[3:0])) begin
                // y_0 <= src.t_data[15: 8];
                // u_0 <= src.t_data[ 7: 0];
                // v_0 <= src.t_data[23:16];

                // Note: Need to clamp
                r_0 <= ((298 * (y_0 - 16)) + (409 * (v_0 - 128)) + 128) >> 8;
                g_0 <= ((298 * (y_0 - 16)) - (100 * (u_0 - 128)) - (208 * (v_0 - 128)) + 128) >> 8;
                b_0 <= ((298 * (y_0 - 16)) + (516 * (y_0 - 128)) + 128) >> 8;
            end

            if (src.t_valid && &(src.t_keep[7:4])) begin
                // y_1 <= src.t_data[47:40];
                // u_1 <= src.t_data[39:32];
                // v_1 <= src.t_data[53:48];

                // Note: Need to clamp
                r_1 <= ((298 * (y_1 - 16)) + (409 * (v_1 - 128)) + 128) >> 8;
                g_1 <= ((298 * (y_1 - 16)) - (100 * (u_1 - 128)) - (208 * (v_1 - 128)) + 128) >> 8;
                b_1 <= ((298 * (y_1 - 16)) + (516 * (y_1 - 128)) + 128) >> 8;
            end
        end
    end
endmodule