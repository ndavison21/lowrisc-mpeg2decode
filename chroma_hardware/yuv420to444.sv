module yuv420to422_noninterp (
    input clk, 
    input rst,

    nasti_stream_channel.slave src,
    nasti_stream_channel.master dst
    );

    logic [63:0] buff [0:15];
    logic [3:0]  read_pointer, write_pointer, elements;
    logic t_last_latch sent;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            buff          <= 0;
            read_pointer  <= 0;
            write_pointer <= 0;
            elements      <= 0;

            src.t_ready <= 1;
            dst.t_last  <= 0;
            sent        <= 0;
        end 
        else begin
            if (elements <= 2) begin
                src.t_ready <= 1;
            end

            if (src.t_last) begin
                t_last_latch <= src.t_last;
                src.t_ready  <= 0;
            end

            if (src.t_ready && (&src.t_keep)) begin
                buff [write_pointer] <= src.t_data;
                write_pointer        <= (write_pointer + 1) % 16;
                elements             <= elements + 1;

                if (elements >= 14) begin
                    src.t_ready <= 0;
                end
            end
            
            if (dst.t_ready && (elements > 0)) begin
                dst.t_keep <= 8'hff;
                dst.t_data <= buff[read_pointer];

                if (sent) begin
                    read_pointer <= (write_pointer + 1) % 16;
                    elements     <= elements - 1;
                    sent         <= 0;
                end else begin
                    sent <= 1;
                end
            end else if (dst.t_ready && t_last_latch) begin
                dst.t_last <= 1;
                t_last_latch <= 0;
            end
        end
    end

endmodule