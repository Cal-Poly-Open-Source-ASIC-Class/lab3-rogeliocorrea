`timescale 1ps/1ps

module tb_dualport();

    logic clk;
    //Addresses diff between rams is MSB
    logic [10:0] pA_wb_addr_i;
    logic [10:0] pB_wb_addr_i;
    
    //Byte selectors
    logic [3:0] pA_wb_sel_i;
    logic [3:0] pB_wb_sel_i;

    //Write enable
    logic pA_wb_we_i;
    logic pB_wb_we_i;

    //Strobes
    logic pA_wb_stb_i;
    logic pB_wb_stb_i;

    //Data in
    logic [31:0] pA_wb_data_i;
    logic [31:0] pB_wb_data_i;

    //Outputs
    logic pA_wb_stall_o;
    logic pA_wb_ack_o;
    logic [31:0] pA_wb_data_o;
    logic pB_wb_stall_o;
    logic pB_wb_ack_o;
    logic [31:0] pB_wb_data_o;

    localparam CLK_PERIOD = 10;

always 
begin
    #(CLK_PERIOD/2) //icarus happy with this, can i go back to vivado pls
    if(clk || !clk)
    clk = ~clk;
    else
    clk = 0;
end

    initial 
    begin
    $dumpfile("tb_dualport.vcd");
    $dumpvars(0);
    end

    dualport dut (.*);

    always 
    begin
        /* Test to show stalls
    pA_wb_stb_i <= 1;
    pB_wb_stb_i <= 1;
    pA_wb_data_i <= 32'hAA; //random stuff
    pB_wb_data_i <= 32'hBB;
    pA_wb_we_i <= 1;
    pB_wb_we_i <= 1;
    pA_wb_sel_i <= 4'b1111;
    pB_wb_sel_i <= 4'b1111;
    pA_wb_addr_i <= 11'b10000000000;
    pB_wb_addr_i <= 11'b10000010000;

    #20;
    pA_wb_data_i <= 0;
    pB_wb_data_i <= 0;
    pA_wb_we_i <= 0;
    pB_wb_we_i <= 0;  
    #60;
    */
    
    //test to show pipelined reads/writes
    pA_wb_stb_i <= 1;
    pA_wb_data_i <= 1;
    pA_wb_addr_i <= 11'b00000000100;
    pA_wb_sel_i <= 4'b1111;
    pA_wb_we_i <= 1; //Write 1
    #10
    pA_wb_data_i <= 32'b00000000000000000000000000000010; //write 2
    pA_wb_addr_i <= 11'b00000001000;
    #10;
    pA_wb_data_i <= 32'b00000000000000000000000000000011; //write 3
    pA_wb_addr_i <= 11'b00000010000;
    #10;
    pA_wb_data_i <= 32'b00000000000000000000000000000100; //write 4
    pA_wb_addr_i <= 11'b00000100000;  
    #10;
    pA_wb_data_i <= 32'b00000000000000000000000000000101; //write 5
    pA_wb_addr_i <= 11'b00001000000;    
    #10;
    pA_wb_we_i <= 0;
    pA_wb_addr_i <= 11'b00000000100; //read 1
    #10;
    pA_wb_addr_i <= 11'b00000001000; //read 2
    #10;
    pA_wb_addr_i <= 11'b00000010000; //read 3
    #10;
    pA_wb_addr_i <= 11'b00000100000; //read 4
    #10;
    pA_wb_addr_i <= 11'b00001000000; //read 5
    #20;
    $finish();
    end


endmodule