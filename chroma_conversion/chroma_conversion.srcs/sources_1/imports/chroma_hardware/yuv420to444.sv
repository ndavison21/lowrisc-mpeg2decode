module yuv420to422_noninterp (
    input clk, 
    input rst,

    nasti_stream_channel.slave src,
    nasti_stream_channel.master dst
    );

    logic [63:0] buff [0:15];
    logic [3:0]  read_pointer, write_pointer, elements; // elements will be one cycle behind
    logic t_last_latch, sent;
    logic write_buff, read_buff; // used to record what happened to the buffer on the previous cycle
    
    logic [3:0] i;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i=0; i< 16; i = i+1)  buff[i] <= 0;

            read_pointer  <= 0;
            write_pointer <= 0;
            elements      <= 0;
            t_last_latch  <= 0;
            write_buff    <= 0;
            read_buff     <= 0;

            src.t_ready <= 1;
            dst.t_last  <= 0;
            sent        <= 0;
        end 
        else begin
            if (elements <= 2) src.t_ready <= 1;

            if (src.t_last) begin
                t_last_latch <= src.t_last;
                src.t_ready  <= 0;
            end

            if (src.t_valid && src.t_ready && (&src.t_keep) && elements<16) begin
                buff [write_pointer] <= src.t_data;
                write_pointer        <= (write_pointer + 1) % 16;
                write_buff           <= 1;

                if (elements >= 14) src.t_ready <= 0;
            end else begin
                write_buff <= 0;
            end
            
            if (dst.t_ready && (elements > 0)) begin
                dst.t_keep <= 8'hff;
                dst.t_data <= buff[read_pointer];

                if (sent) begin
                    read_pointer <= (read_pointer + 1) % 16;
                    read_buff    <= 1;
                    sent         <= 0;
                end else sent <= 1;

            end else if (dst.t_ready && t_last_latch) begin
                dst.t_last <= 1;
                t_last_latch <= 0;
            end
        end
    end

endmodule