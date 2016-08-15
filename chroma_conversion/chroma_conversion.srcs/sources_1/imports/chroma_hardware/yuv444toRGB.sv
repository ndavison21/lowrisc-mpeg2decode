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