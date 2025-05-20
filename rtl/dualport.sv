`timescale 1ns/1ps

module dualport (
    input wire clk,
    //Addresses diff between rams is MSB
    input wire [10:0] pA_wb_addr_i,
    input wire [10:0] pB_wb_addr_i,
    
    //write selects
    input wire [3:0] pA_wb_sel_i,
    input wire [3:0] pB_wb_sel_i,

    //Write enable
    input wire pA_wb_we_i,
    input wire pB_wb_we_i,

    //Strobes
    input wire pA_wb_stb_i,
    input wire pB_wb_stb_i,

    //Data in
    input wire [31:0] pA_wb_data_i,
    input wire [31:0] pB_wb_data_i,

    //Outputs
    output logic pA_wb_stall_o,
    output logic pA_wb_ack_o,
    output logic [31:0] pA_wb_data_o,
    output logic pB_wb_stall_o,
    output logic pB_wb_ack_o,
    output logic [31:0] pB_wb_data_o
);

//Collision check
wire collision = (pA_wb_addr_i[10] == pB_wb_addr_i[10]) && (pA_wb_stb_i && pB_wb_stb_i);

logic stallA, stallB;

//RAM addresses
logic [7:0] addrA, addrB;

//RAM enable
logic ramAen, ramBen;

//RAM WE
logic [3:0] ramAWE, ramBWE;

//Buffers so i can manipulate outputsw
logic [31:0] aBuffer, bBuffer;

logic [31:0] aIn, bIn;

//ports take turns with collision priorities
logic turn = 0;

//Indicates if pA accesses RAMA and if pB accesses RAMb
wire aAta = pA_wb_addr_i[10];
wire bAtb = ~pB_wb_addr_i[10];

//icarus doesnt like pA_wb_addr_i[9:2] in always_comb for some reason :(
wire [7:0]pAaddr = pA_wb_addr_i[9:2];
wire [7:0]pBaddr = pB_wb_addr_i[9:2];

//same reason as above
wire pA_ram_sel = pA_wb_addr_i[10];
wire pB_ram_sel = pB_wb_addr_i[10];

always_comb 
begin
addrA = 0;
addrB = 0;
aIn = 0;
bIn = 0;
stallA = 0;
stallB = 0;
ramAen = 0;
ramBen = 0;

if (!collision) 
    begin
    if(pA_wb_stb_i && !stallA)
        begin
            //pA accesses RAM A
            if (pA_ram_sel) 
            begin
                addrA = pAaddr;
                aIn = pA_wb_data_i;
                ramAen = 1;
            end 
            else
            //pA accesses RAM B
            begin
                addrB = pAaddr;
                bIn = pA_wb_data_i;
                ramBen = 1;
            end
        end 
    if(pB_wb_stb_i && !stallB)
        begin
        if(pB_ram_sel) //pB acces ramA
            begin
                addrA = pBaddr;
                aIn = pB_wb_data_i;
                ramAen = 1;
            end
        else //pB access ramB
        begin
            addrB = pBaddr;
            bIn = pB_wb_data_i;
            ramBen = 1;
        end
        end
    end
else 
    begin
        if (turn) 
        //B's turn
        begin 
            if (pB_ram_sel) 
            begin
                addrA = pBaddr;
                aIn = pB_wb_data_i;
                stallA = 1;
                ramAen = 1;
            end else 
            begin
                addrB = pBaddr;
                bIn = pB_wb_data_i;
                stallA = 0;
                ramBen = 1;
            end
        end 
        else 
        //A's turn
        begin
            if (pA_ram_sel) 
            begin
                addrA = pAaddr;
                aIn = pA_wb_data_i;
                stallB = 1;
                ramAen = 1;
            end 
            else 
            begin
                addrB = pAaddr;
                bIn = pA_wb_data_i;
                stallB = 1;
                ramBen = 1;
            end
        end
    end
end

always_comb 
begin
    ramAWE = 4'b0000;
    ramBWE = 4'b0000;

    
    if(pA_wb_stb_i)
    begin
        //pA writes
        if (pA_wb_we_i && !stallA) //if we are writing
        begin
            if(aAta) //routing WE signal to ramA
            begin
                ramAWE = pA_wb_sel_i;
            end
            else if(!aAta)//pA getting routed to ramB, my naming is probably the worst choice for this aside from not using structs and an FSM
            begin
                ramBWE = pA_wb_sel_i;
            end
        end
    end

    if(pB_wb_stb_i)
    begin
        //pB writes
        if (pB_wb_we_i && !stallB) 
        begin
            if(bAtb) //routing WE signal to ramB
            begin
                ramBWE = pB_wb_sel_i;
            end
            else if(!bAtb) //pB getting routed to ramA
            begin
                ramAWE = pB_wb_sel_i;
            end        
        end
    end
end

always_ff @(posedge clk) 
begin
    pA_wb_ack_o <= 0;
    pB_wb_ack_o <= 0;
    turn <= 0;

    if(collision && (turn || !turn)) turn <= ~turn; //idr why else statement
    else turn <= 0;

    if(pA_wb_stb_i)
    begin
        if(!collision) pA_wb_ack_o <= 1; //no collision yay
        else
        begin
            if(stallA) pA_wb_ack_o <= 0; //not A's turn
            else pA_wb_ack_o <= 1; //A's turn
        end
    end

    if(pB_wb_stb_i)
    begin
        if(!collision) pB_wb_ack_o <= 1; //no collision yay
        else
        begin
            if(stallB) pB_wb_ack_o <= 0; //not B's turn
            else pB_wb_ack_o <= 1; //B's turn
        end
    end
end

assign pA_wb_stall_o = stallA;
assign pB_wb_stall_o = stallB;

//assigning first byte, halfword, and most significant byte
wire [7:0]abytel = aBuffer[15:8];
wire [15:0]ahw = aBuffer[31:16];
wire [7:0]abytem = aBuffer[31:24];

wire [7:0]bbytel = bBuffer[15:8];
wire [15:0]bhw = bBuffer[31:16];
wire [7:0]bbytem = bBuffer[31:24];

//assining byte selectors, 2 least significant bits of the input addressses
wire [1:0]pAsel = pA_wb_addr_i[1:0];
wire [1:0]pBsel = pB_wb_addr_i[1:0];

//connecting outputs to ports depending on which port connected to which ram
always_comb
begin
pA_wb_data_o = 0;
pB_wb_data_o = 0;


if(aAta)
    begin
        case(pAsel)
        2'b00: pA_wb_data_o = aBuffer; //full word
        2'b01: pA_wb_data_o = {24'b0, abytel}; //1 byte into the buffer
        2'b10: pA_wb_data_o = {16'b0, ahw}; //halfword in the second half of the buffer
        2'b11: pA_wb_data_o = {24'b0, abytem}; //last byte 
        endcase 
    end

if(!aAta)
    begin
        case(pAsel)
        2'b00: pA_wb_data_o = bBuffer; //full word
        2'b01: pA_wb_data_o = {24'b0, bbytel}; //1 byte into the buffer
        2'b10: pA_wb_data_o = {16'b0, bhw}; //halfword in the second half of the buffer
        2'b11: pA_wb_data_o = {24'b0, bbytem}; //last byte 
        endcase  
    end          


if(bAtb)
    begin
        case(pBsel)
        2'b00: pB_wb_data_o = bBuffer; //full word
        2'b01: pB_wb_data_o = {24'b0, bbytel}; //1 byte into the buffer
        2'b10: pB_wb_data_o = {16'b0, bhw}; //halfword in the second half of the buffer
        2'b11: pB_wb_data_o = {24'b0, bbytem}; //last byte 
        endcase
    end

if(!bAtb)
    begin
        case(pBsel)
        2'b00: pB_wb_data_o = aBuffer; //full word
        2'b01: pB_wb_data_o = {24'b0, abytel}; //1 byte into the buffer
        2'b10: pB_wb_data_o = {16'b0, ahw}; //halfword in the second half of the buffer
        2'b11: pB_wb_data_o = {24'b0, abytem}; //last byte 
        endcase            
    end

end

//ram instances
DFFRAM256x32 ramA(
    .CLK(clk),
    .WE0(ramAWE),
    .EN0(ramAen),
    .Di0(aIn),
    .Do0(aBuffer),
    .A0(addrA)
);

DFFRAM256x32 ramB(
    .CLK(clk),
    .WE0(ramBWE),
    .EN0(ramBen),
    .Di0(bIn),
    .Do0(bBuffer),
    .A0(addrB)
);

endmodule