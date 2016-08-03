// See LICENSE for license details.

// Define the SV interfaces for NASTI-Stream channels

interface nasti_stream_channel #(
   N_PORT = 1,                 // number of nasti stream ports
   ID_WIDTH = 1,               // id width
   DEST_WIDTH = 1,             // destination width
   USER_WIDTH = 1,             // width of user
   DATA_WIDTH = 64             // width of data
);
   logic [N_PORT-1:0]                   t_valid;
   logic [N_PORT-1:0]                   t_ready;
   logic [N_PORT-1:0][DATA_WIDTH-1:0]   t_data;
   logic [N_PORT-1:0][DATA_WIDTH/8-1:0] t_strb;
   logic [N_PORT-1:0][DATA_WIDTH/8-1:0] t_keep;
   logic [N_PORT-1:0]                   t_last;
   logic [N_PORT-1:0][ID_WIDTH-1:0]     t_id;
   logic [N_PORT-1:0][DEST_WIDTH-1:0]   t_dest;
   logic [N_PORT-1:0][USER_WIDTH-1:0]   t_user;

   modport master (
      output t_valid,
      input  t_ready,
      output t_data,
      output t_strb,
      output t_keep,
      output t_last,
      output t_id,
      output t_dest,
      output t_user
   );

   modport slave (
      input  t_valid,
      output t_ready,
      input  t_data,
      input  t_strb,
      input  t_keep,
      input  t_last,
      input  t_id,
      input  t_dest,
      input  t_user
   );

endinterface // nasti_channel
