module top_tm1638_demo(
    input clk,

    output reg tm_cs,
    output tm_clk,
    inout  tm_dio
    );

    localparam 
        HIGH    = 1'b1,
        LOW     = 1'b0;

    localparam [6:0]
        S_1     = 7'b0000110,
        S_2     = 7'b1011011,
        S_3     = 7'b1001111,
        S_4     = 7'b1100110,
        S_5     = 7'b1101101,
        S_6     = 7'b1111101,
        S_7     = 7'b0000111,
        S_8     = 7'b1111111,
        S_9     = 7'b1101111,
        S_strip = 7'b1000000,
        S_t     = 7'b1111000,
        S_e     = 7'b1111011,
        S_BLK   = 7'b0000000;

    localparam [7:0]
        C_READ  = 8'b01000010,
        C_WRITE = 8'b01000000,
        C_DISP  = 8'b10001111,
        C_ADDR  = 8'b11000000;

    localparam CLK_DIV = 21; // speed of scanner
    // localparam CLK_DIV = 18; // speed of scanner

    reg rst = HIGH;

    reg [5:0] instruction_step;
    reg [7:0] keys;

    reg [7:0] larson;
    reg larson_dir;
    reg [CLK_DIV:0] counter;

    reg [6:0] character [33:0];
    
    reg text_dir;
    reg [4:0] state;

    // initial begin
    //     character[0] = 7'b0000000;
    //     character[1] = 7'b0000000;
    //     character[2] = 7'b0000000;
    //     character[3] = 7'b0000000;
    //     character[4] = 7'b0000000;
    //     character[5] = 7'b0000000;
    //     character[6] = 7'b0000000;
    //     character[7] = 7'b0000000;
    //     character[8] = S_2;
    //     character[9] = S_3;
    //     character[10] = S_strip;
    //     character[11] = S_5;
    //     character[12] = S_1;
    //     character[13] = S_3;
    //     character[14] = S_1;
    //     character[15] = S_8;
    //     character[16] = S_9;
    //     character[17] = S_strip;
    //     character[18] = S_t;
    //     character[19] = S_e;
    //     character[20] = S_strip;
    //     character[21] = S_5;
    //     character[22] = S_6;
    //     character[23] = S_3;
    //     character[24] = S_9;
    //     character[25] = S_8;
    //     character[26] = 7'b0000000;
    //     character[27] = 7'b0000000;
    //     character[28] = 7'b0000000;
    //     character[29] = 7'b0000000;
    //     character[30] = 7'b0000000;
    //     character[31] = 7'b0000000;
    //     character[32] = 7'b0000000;
    //     character[33] = 7'b0000000;
    // end

    // set up tristate IO pin for display
    //   tm_dio     is physical pin
    //   dio_in     for reading from display
    //   dio_out    for sending to display
    //   tm_rw      selects input or output
    reg tm_rw;
    wire dio_in, dio_out;
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(tm_rw),
        .D_IN_0(dio_in),
        .D_OUT_0(dio_out)
    );

    // setup tm1638 module with it's tristate IO
    //   tm_in      is read from module
    //   tm_out     is written to module
    //   tm_latch   triggers the module to read/write display
    //   tm_rw      selects read or write mode to display
    //   busy       indicates when module is busy
    //                (another latch will interrupt)
    //   tm_clk     is the data clk
    //   dio_in     for reading from display
    //   dio_out    for sending to display
    //
    //   tm_data    the tristate io pin to module
    wire tm_latch, busy;
    wire [7:0] tm_data, tm_in;
    reg [7:0] tm_out;

    assign tm_in = tm_data;
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    tm1638 u_tm1638 (
        .clk(clk),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );

    // handles displaying 1-8 on a display location
    // and animating the decimal point
    task display_digit;
        input [2:0] key;
        input [6:0] segs;

        begin
            tm_latch <= HIGH;

            if (keys[key])
                tm_out <= {1'b1, S_BLK[6:0]}; // decimal on
            else
                tm_out <= {1'b0, segs}; // decimal off
        end
    endtask

    // handles animating the LEDs 1-8
    task display_led;
        input [2:0] dot;

        begin
            tm_latch <= HIGH;
            tm_out <= {7'b0, larson[dot]};
        end
    endtask


    function [6:0] digit_solver;
        input [2:0] index;
        input [4:0] state;

        integer pos;
        integer int_index;
        integer int_state;

        begin
            int_index = index;
            int_state = state;
            pos = int_state - int_index - 1;
            case (pos)
                0:  digit_solver = S_2;
                1:  digit_solver = S_3;
                2:  digit_solver = S_strip;
                3:  digit_solver = S_5;
                4:  digit_solver = S_1;
                5:  digit_solver = S_3;
                6:  digit_solver = S_1;
                7:  digit_solver = S_8;
                8:  digit_solver = S_9;
                9:  digit_solver = S_strip;
                10: digit_solver = S_t;
                11: digit_solver = S_e;
                12: digit_solver = S_strip;
                13: digit_solver = S_5;
                14: digit_solver = S_6;
                15: digit_solver = S_3;
                16: digit_solver = S_9;
                17: digit_solver = S_8;
                default: digit_solver = 7'b0000000; 
            endcase
        end
    endfunction

    reg [1:0] display_mode;     
    reg [1:0] switch_value_prev;
    always @(posedge clk) begin
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
            rst <= LOW;

            counter <= 0;
            keys <= 8'b0;
            larson_dir <= 0;
            larson <= 8'b00010000;
            state <= 5'b0;
            text_dir <= 1'b0;
            display_mode <= 2'b00;      
            switch_value_prev <= 2'b00;

        end else begin
            if (&counter) begin // This one will reset if value of all counter reg is all 1s
                larson_dir <= larson[6] ? 0 : larson[1] ? 1 : larson_dir;

                if (larson_dir)
                    larson <= {larson[6:0], larson[7]};
                else
                    larson <= {larson[0], larson[7:1]};
                if (text_dir == 0) begin
                    if (state >= 26) text_dir <= 1; // Reached left edge, turn around
                    else state <= state + 1;
                end else begin
                    if (state == 0) text_dir <= 0;  // Reached right edge, turn around
                    else state <= state - 1;
                end
            end

            if (counter[0] && ~busy) begin
                case (instruction_step)
                    // *** KEYS ***
                    1:  {tm_cs, tm_rw}     <= {LOW, HIGH};
                    2:  {tm_latch, tm_out} <= {HIGH, C_READ}; // read mode
                    3:  {tm_latch, tm_rw}  <= {HIGH, LOW};

                    //  read back keys S1 - S8
                    4:  {keys[7], keys[3]} <= {tm_in[0], tm_in[4]};
                    5:  {tm_latch}         <= {HIGH};
                    6:  {keys[6], keys[2]} <= {tm_in[0], tm_in[4]};
                    7:  {tm_latch}         <= {HIGH};
                    8:  {keys[5], keys[1]} <= {tm_in[0], tm_in[4]};
                    9:  {tm_latch}         <= {HIGH};
                    10: {keys[4], keys[0]} <= {tm_in[0], tm_in[4]};
                    11: {tm_cs}            <= {HIGH};
                    12: begin
                            if (({keys[1], keys[0]} != 2'b00) && ({keys[1], keys[0]} != switch_value_prev)) begin
                                    display_mode <= {keys[1], keys[0]};
                                end
                            switch_value_prev <= {keys[1], keys[0]};
                        end
                    13: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    14: {tm_latch, tm_out} <= {HIGH, C_WRITE}; // write mode
                    15: {tm_cs}            <= {HIGH};

                    16: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    17: {tm_latch, tm_out} <= {HIGH, C_ADDR}; // set addr 0 pos

                    19: display_digit(3'd7, digit_solver(3'd7, state)); // Digit 1
                    20: display_led(3'd0);        // LED 1

                    22: display_digit(3'd6, digit_solver(3'd6, state)); // Digit 2
                    23: display_led(3'd1);        // LED 2

                    25: display_digit(3'd5, digit_solver(3'd5, state)); // Digit 3
                    26: display_led(3'd2);        // LED 3

                    28: display_digit(3'd4, digit_solver(3'd4, state)); // Digit 4
                    29: display_led(3'd3);        // LED 4

                    31: display_digit(3'd3, digit_solver(3'd3, state)); // Digit 5
                    32: display_led(3'd4);        // LED 5

                    34: display_digit(3'd2, digit_solver(3'd2, state)); // Digit 6
                    35: display_led(3'd5);        // LED 6

                    37: display_digit(3'd1, digit_solver(3'd1, state)); // Digit 7
                    38: display_led(3'd6);        // LED 7

                    40: display_digit(3'd0, digit_solver(3'd0, state)); // Digit 8
                    41: display_led(3'd7);        // LED 8

                    42: {tm_cs}            <= {HIGH};

                    43: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    44: {tm_latch, tm_out} <= {HIGH, C_DISP}; // display on, full bright
                    45: {tm_cs, instruction_step} <= {HIGH, 6'b0};

                endcase

                instruction_step <= instruction_step + 1;

            end else if (busy) begin
                // pull latch low next clock cycle after module has been
                // latched
                tm_latch <= LOW;
            end

            counter <= counter + 1;
        end
    end
endmodule
