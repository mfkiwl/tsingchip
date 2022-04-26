/**
 * @module uart_din
 * @author {yuxuan-z19} (yuxuan-z19@mails.tsinghua.edu.cn)
 * @brief UART data input buffer, specialized for list of 2d matrices 
            - support customizing data width + count of elements received 
            - adjustable clock frequency, baudrate
 * @date 2022-02-29
 * @copyright Neuromorphic Group, CST HPC, Tsinghua University, China
 */
module uart_din #(
    /** Data-related **/
    parameter DATAWIDTH = 32, // Data width, defaults to 32-bit
    parameter BUFLEN = 32, // Size of the buffer, defaults to 32 digits
    /** Data-related **/

    /** Engineering-related **/
    parameter CLK_FREQ = 50000000, // Clock frequency, defaults to 50M Hz
    parameter BAUD = 9600   // Baudrate, defaults to 9600 Hz
    /** Engineering-related **/
) (
    input wire clk,
    input wire rst,
    input wire clr, // sync reset
    input wire select,
    output reg done,

    input wire rxd,
    input integer count,  // number of digits to be transmitted
    output reg [DATAWIDTH-1 : 0] din [BUFLEN]
);

    localparam PAYLOAD_BITS = 8; // Payload
    localparam BUFSIZE = DATAWIDTH / PAYLOAD_BITS;
    reg[$clog2(BUFSIZE) : 0] offset = 0; // offset of current element
    int idx = 0; // index of list

    wire [7:0] ext_uart_rx; 
    reg [7:0] ext_uart_buffer;
    wire ext_uart_ready, ext_uart_clear; 
    reg ext_uart_avai;

    async_receiver #(.ClkFrequency(CLK_FREQ),.Baud(BAUD))
        ext_uart_r(
            .clk(clk),
            .RxD(rxd),
            .RxD_data_ready(ext_uart_ready),
            .RxD_clear(ext_uart_clear),
            .RxD_data(ext_uart_rx)
        );

    assign ext_uart_clear = ext_uart_ready; // the data is stored once it's accepted
    always_ff @(posedge clk, posedge rst) begin
        if (rst | clr) begin
            din <= '{default:'0}; 
            ext_uart_buffer <= 0;
            offset <= 0; idx <= 0; 
            done <= 0; ext_uart_avai <= 0;
        end else if (select) begin
            if (ext_uart_ready) begin
                din[idx][offset * PAYLOAD_BITS +: PAYLOAD_BITS] <= ext_uart_rx;
                ext_uart_avai <= 1; done <= 0;
            end else if (ext_uart_avai) begin
                if (offset + 1 == BUFSIZE) begin 
                    if (idx + 1 == count) begin done <= 1; end
                    else begin ++idx; done <= 0; end
                    offset <= 0;
                end else begin ++offset; done <= 0; end
                ext_uart_avai <= 0;
            end
        end
    end

endmodule


/**
 * @module uart_dout
 * @author {yuxuan-z19} (yuxuan-z19@mails.tsinghua.edu.cn)
 * @brief UART data output buffer, specialized for list of 2d matrices 
            - support customizing data width + count of elements pending for transmission 
            - adjustable clock frequency, baudrate
 * @date 2022-02-29
 * @copyright Neuromorphic Group, CST HPC, Tsinghua University, China
 */
module uart_dout #(
    /** Data-related **/
    parameter DATAWIDTH = 32, // Data width, defaults to 32-bit
    parameter BUFLEN = 32, // Size of the buffer, defaults to 32 digits
    /** Data-related **/

    /** Engineering-related **/
    parameter CLK_FREQ = 50000000, // Clock frequency, defaults to 50M Hz
    parameter BAUD = 9600   // Baudrate, defaults to 9600 Hz
    /** Engineering-related **/
) (
    input wire clk,
    input wire rst,
    input wire clr, // sync reset
    input wire select,
    output reg done,

    output wire txd,
    input integer count, // number of digits to be transmitted
    input wire [DATAWIDTH-1 : 0] dout [BUFLEN]
);

    localparam PAYLOAD_BITS = 8; // Payload
    localparam BUFSIZE = DATAWIDTH / PAYLOAD_BITS;
    reg[$clog2(BUFSIZE) : 0] offset = 0; // offset of current element
    int idx = 0; // index of list

    reg [7:0] ext_uart_tx;
    wire ext_uart_busy; reg ext_uart_start;

    async_transmitter #(.ClkFrequency(CLK_FREQ),.Baud(BAUD))
    ext_uart_t(
        .clk(clk),
        .TxD(txd),
        .TxD_busy(ext_uart_busy),
        .TxD_start(ext_uart_start),
        .TxD_data(ext_uart_tx)
    );

    always_ff @(posedge clk, posedge rst) begin // transmit ext_uart_buffer
        if (rst | clr) begin
            ext_uart_tx <= 0;
            offset <= 0; idx <= 0;
            done <= 0; ext_uart_start <= 0;
        end else if (select & !done) begin
            if (!ext_uart_busy) begin
                ext_uart_tx <= dout[idx][offset * PAYLOAD_BITS +: PAYLOAD_BITS];
                ext_uart_start <= 1; done <= 0;
            end else if (ext_uart_start) begin
                if (offset + 1 == BUFSIZE) begin 
                    if (idx + 1 == count) begin done <= 1; end 
                    else begin ++idx; done <= 0; end
                    offset <= 0;
                end else begin ++offset; done <= 0; end
                ext_uart_start <= 0;
            end
        end
    end

endmodule