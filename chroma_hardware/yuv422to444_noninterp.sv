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
*  |   V    |   U    |   Y0   | 0 Byte |   V    |   U    |   Y1   | 0 Byte |
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
            t_last_latch  <= 0;
            src.t_ready   <= 1;
            dst.t_last    <= 0;
            dst.t_valid   <= 0;
            to_send       <= 0;
            locked        <= 0;     // Freeze the pipeline if something is not ready
            dst.t_keep    <= 8'hff; // We send data in 'pairs', so what we send will always be kept.
                                   // We could ignore 4th byte, since this is only used to bring it 
                                   // up to 32 bits per pixel, but it's simpler to check this way.
        end 
        else begin
            if (!src.t_valid || !dst.t_ready) begin
                locked <= 1;
            end
            else if (locked && src.t_valid && dst.t_ready) begin
                locked <= 0;
            end
            else if (!locked) begin // The actual pipeline
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
                    if (src.t_valid && &(src.t_keep[0][3:0])) begin
                        dst.t_valid <= 1;

                        dst.t_data[0][ 7: 0] <= src.t_data[0][31:24]; // v
                        dst.t_data[0][15: 8] <= src.t_data[0][15: 8]; // u
                        dst.t_data[0][23:16] <= src.t_data[0][ 7: 0]; // y0
                        dst.t_data[0][31:24] <= 8'b0;
                        
                        dst.t_data[0][39:32] <= src.t_data[0][31:24]; // v
                        dst.t_data[0][47:40] <= src.t_data[0][15: 8]; // u
                        dst.t_data[0][55:48] <= src.t_data[0][23:16]; // y1
                        dst.t_data[0][63:56] <= 8'b0;
                    end
                    // If there is an odd number of pixels then we may not need the second half
                    // All resolutions are powers of 2 now, so it's probably not going to happen
                    // that this does not run
                    if (&(src.t_keep[0][7:4])) begin
                        to_send <= 1;
                        src.t_ready <= 0;
                        y0 <= src.t_data[0][39:32];
                        u  <= src.t_data[0][47:40];
                        y1 <= src.t_data[0][55:48];
                        v  <= src.t_data[0][63:56];
                    end
                end
                else if (src.t_valid && to_send && dst.t_ready) begin
                    dst.t_valid <= 1;
                    src.t_ready <= 1;
                    to_send <= 0;

                    dst.t_data[0][ 7: 0] <= v;
                    dst.t_data[0][15: 8] <= u;
                    dst.t_data[0][23:16] <= y0;
                    dst.t_data[0][31:24] <= 8'b0;
                    
                    dst.t_data[0][39:32] <= v;
                    dst.t_data[0][47:40] <= u;
                    dst.t_data[0][55:48] <= y0;
                    dst.t_data[0][63:56] <= 8'b0;

                    if (t_last_latch) begin
                        dst.t_last <= 1;
                    end
                end
            end
        end
    end
endmodule