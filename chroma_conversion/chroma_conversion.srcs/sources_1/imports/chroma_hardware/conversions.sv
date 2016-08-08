/* MUST INTERLEAVE YUV BEFORE SENDING TO THIS STREAM PROCESSOR
*  Input is packed Y'UV422:
*  -------------------------------------
*  |   Y0   |   U    |   Y1   |   V    |
*  -------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
*  -------------------------------------
*
* Output is packed Y'UV444:
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

    logic        to_send, t_last_latch, locked;
    logic [63:0] data;
    logic [ 7:0] y0, y1, u, v;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            t_last_latch <= 0;
            src.t_ready  <= 1;
            dst.t_last   <= 0;
            dst.t_valid  <= 0;
            to_send      <= 0;
            locked       <= 0;
            dst.t_keep   <= 8'hff; // We send data in 'pairs', so what we send will always be kept
                                   // I guess we could actually say not to keep the 4th byte, since
                                   // we only use this to bring it up to 32 bits per pixel, but 
                                   // it's simpler to check this way.
        end 
        else begin
            if (!src.t_valid || !dst.t_ready) begin
                locked <= 1;
            end
            else if (locked && src.t_valid && dst.t_ready) begin
                locked <= 0;
            end
            else if (!locked) begin
                if (src.t_last) begin
                    t_last_latch <= 1;
                end
                else if (t_last_latch && dst.t_last) begin
                    // Hold last for one cycle
                    dst.t_valid <= 0;
                    t_last_latch <= 0;
                end

                if (!dst.t_ready) begin
                    // Do we have the potential to lose a cycle of data here? Yes I think so. Fix?
                    src.t_ready <= 0;
                    to_send <= 0;
                end
                else if (src.t_valid && !to_send && dst.t_ready) begin
                    // Expected format is shown in module preamble
                    // (it is the standard packed YUV422 format)
                    if (src.t_valid && &(src.t_keep[3:0])) begin
                        dst.t_valid <= 1;

                        dst.t_data[ 7: 0] <= src.t_data[15: 8]; // u  <= src.t_data[15:8];
                        dst.t_data[15: 8] <= src.t_data[ 6: 0]; // y0 <= src.t_data[ 6:0];
                        dst.t_data[23:16] <= src.t_data[31:24]; // v  <= src.t_data[32:24];
                        dst.t_data[31:24] <= 8'b0;
                        
                        dst.t_data[39:32] <= src.t_data[15: 8]; // u  <= src.t_data[15:8];
                        dst.t_data[47:40] <= src.t_data[23:16]; // y1 <= src.t_data[23:16];
                        dst.t_data[53:48] <= src.t_data[31:24]; // v  <= src.t_data[32:24];
                        dst.t_data[61:54] <= 8'b0;
                    end
                    // If there is an odd number of pixels then we may not need the second half
                    // All resolutions are powers of 2 now, so it's probably not going to happen
                    // that this does not run
                    if (&(src.t_keep[7:4])) begin
                        to_send <= 1;
                        src.t_ready <= 0;
                        y0 <= src.t_data[ 7:0];
                        u  <= src.t_data[15:8];
                        y1 <= src.t_data[23:16];
                        v  <= src.t_data[32:24];
                    end
                end
                else if (src.t_valid && to_send && dst.t_ready) begin
                    dst.t_valid <= 1;
                    src.t_ready <= 1;
                    to_send <= 0;

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
    end
endmodule


/*
* Input is Packed Y'UV 444:
*  -------------------------------------------------------------------------
*  |   U    |   Y0   |   V    | 0 Byte |   U    |   Y1   |   V    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
* Output is  RGB:
*  -------------------------------------------------------------------------
*  |   R    |   G    |   B    | 0 Byte |   R    |   G    |   B    | 0 Byte |
*  -------------------------------------------------------------------------
*  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | Byte 4 | Byte 5 | Byte 6 | Byte 7 |
*  -------------------------------------------------------------------------
*
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

    logic to_convert_0, to_convert_1, to_clamp_0, to_clamp_1;
    logic t_last_latch;


    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            src.t_ready <= 1;
            dst.t_valid <= 0;
            dst.t_last  <= 0;

            to_convert_0 <= 0;
            to_convert_1 <= 0;
            to_clamp_0   <= 0;
            to_clamp_1   <= 0;

            t_last_latch <= 0;
        end
        else begin
            if (!src.t_valid || !dst.t_ready) begin
                src.t_ready <= 0;
                locked      <= 1;
            end
            else if (locked && dst.t_ready && src.t_valid) begin 
                src.t_ready <= 1;
                locked      <= 0;
            end
            else if (!locked) begin
                t_last_latch <= src.t_last;

                to_convert_0 <= !t_last_latch;
                to_convert_1 <= !t_last_latch;
                to_clamp_0   <= to_convert_0;
                to_clamp_1   <= to_convert_1;

                // It's a pipeline yo

                // First, read data
                if (&(src.t_keep[2:0]) && !t_last_latch) begin
                    y_0 <= src.t_data[15: 8];
                    u_0 <= src.t_data[ 7: 0];
                    v_0 <= src.t_data[23:16];
                end

                if (&(src.t_keep[6:4]) && !t_last_latch) begin
                    y_1 <= src.t_data[47:40];
                    u_1 <= src.t_data[39:32];
                    v_1 <= src.t_data[53:48];
                end

                // Next, convert data
                if (to_convert_0) begin    
                    r_0 <= ((298 * (y_0 - 16)) + (409 * (v_0 - 128)) + 128) >> 8;
                    g_0 <= ((298 * (y_0 - 16)) - (100 * (u_0 - 128)) - (208 * (v_0 - 128)) + 128) >> 8;
                    b_0 <= ((298 * (y_0 - 16)) + (516 * (y_0 - 128)) + 128) >> 8;
                end 

                if (to_convert_1) begin
                    r_1 <= ((298 * (y_1 - 16)) + (409 * (v_1 - 128)) + 128) >> 8;
                    g_1 <= ((298 * (y_1 - 16)) - (100 * (u_1 - 128)) - (208 * (v_1 - 128)) + 128) >> 8;
                    b_1 <= ((298 * (y_1 - 16)) + (516 * (y_1 - 128)) + 128) >> 8;
                end

                // Finally, clamp and send
                if (to_convert_0 || to_convert_1) dst.t_valid <= 1;
                else dst.t_valid <= 0;

                if (to_convert_0) begin
                    dst.t_data[ 7: 0] <= r0 > 255 ? 255 : r0;
                    dst.t_data[15: 8] <= g0 > 255 ? 255 : g0;
                    dst.t_data[23:16] <= b0 > 255 ? 255 : b0;
                    dst.t_data[31:24] <= 8'b0;

                    if (t_last_latch && !to_convert_0 && !to_convert_1) begin
                        dst.t_last <= 0; 
                        dst.t_valid <= 1;
                    end
                    else dst.t_valid <= 1;
                end

                if (to_convert_1) begin
                    dst.t_data[39:32] <= r1 > 255 ? 255 : r1;
                    dst.t_data[47:40] <= g1 > 255 ? 255 : g1;
                    dst.t_data[55:48] <= b1 > 255 ? 255 : b1;
                    dst.t_data[63:56] <= 8'b0;
                end
            end
        end
    end
endmodule