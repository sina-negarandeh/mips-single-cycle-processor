module MIPS(clk,rst);
  input clk;
  input rst;
  
  wire [1:0]regDst;
  wire ALUSrc;
  wire [2:0]ALUOperation;
  wire memRead;
  wire memWrite;
  wire regWrite;
  wire [1:0]memToReg;
  wire [1:0]PCSrc;
  wire [5:0]OPC;
  wire [5:0]func;
  wire zero;
  
  dataPath DP(clk,rst,regDst,ALUSrc,regWrite,ALUOperation,memRead,memWrite,memToReg,PCSrc,OPC,func,zero);
  ControlUnit CU(OPC,func,zero,regDst,ALUSrc,memToReg,regWrite,memRead,memWrite,ALUOperation,PCSrc);
endmodule

module dataPath(clk,rst,regDst,ALUSrc,regWrite,ALUOperation,memRead,memWrite,memToReg,PCSrc,OPC,func,zero);
  input clk;
  input rst;
  input [1:0]regDst;
  input [2:0]ALUOperation;
  input memRead;
  input memWrite;
  input ALUSrc;
  input [1:0]memToReg;
  input regWrite;
  input [1:0]PCSrc;
  output [5:0]OPC;
  output [5:0]func;
  output zero;
  
  wire [31:0]newPC;
  wire [31:0]PC;
  wire [31:0]instruction;
  wire [4:0]writeReg;
  wire [31:0]writeData;
  wire [31:0]readData1;
  wire [31:0]readData2;
  wire [31:0]extended;
  wire [31:0]B;
  wire [31:0]ALUResult;
  wire [31:0]readData;
  wire [31:0]PCplus4;
  wire [27:0]shifted28;
  wire [31:0]shifted32;
  wire [31:0]sum;
  
  assign OPC = instruction[31:26];
  assign func = instruction[5:0];
  PCReg pc(newPC,clk,rst,PC);
  instructionMemory IM(PC,clk,rst,instruction);
  mux3 MX3(instruction[20:16],instruction[15:11],5'b11111,regDst,writeReg);
  registerFile RF(instruction[25:21],instruction[20:16],writeReg,writeData,regWrite,clk,rst,readData1,readData2);
  signExtend SE(instruction[15:0],extended);
  mux2 MX2(readData2,extended,ALUSrc,B);
  ALU alu(readData1, B, ALUOperation, zero, ALUResult);
  dataMemory DM(ALUResult,readData2,memRead,memWrite,clk,rst,readData);
  adder32 AD4(PC,32'b00000000000000000000000000000100,PCplus4);
  mux4 MX4_1(ALUResult,readData,PCplus4,,memToReg,writeData);
  shL2_26 SHL26(instruction[25:0],shifted28);
  shL2_32 SHL32(extended,shifted32);
  adder32 ADD(PCplus4,shifted32,sum);
  mux4 MX4_2(sum,PCplus4,readData1,{PC[31:28],shifted28},PCSrc,newPC);
endmodule

module signExtend (Input, Output);
  input [15:0]Input;
  output [31:0]Output;
  
  assign Output = {{16{Input[15]}}, Input[15:0]};
endmodule

module mux4 (A, B, C, D, S, out);
  input [31:0]A;
  input [31:0]B;
  input [31:0]C;
  input [31:0]D;
  input [1:0]S;
  output reg [31:0]out;
  
  always @ (A, B, C, S) begin
    out = 32'b0;
    case(S)
      2'b00: out = A;
      2'b01: out = B;
      2'b10: out = C;
      2'b11: out = D;
    endcase
  end
endmodule

module mux3 (A, B, C, S, out);
  input [4:0]A;
  input [4:0]B;
  input [4:0]C;
  input [1:0]S;
  output reg [4:0]out;
  
  always @ (A, B, C, S) begin
    out = 5'b0;
    if (S == 2'b00)
      out = A;
    else if (S == 2'b01)
      out = B;
    else if (S == 2'b10)
      out = C;
    else
      out = 5'b0;
  end
endmodule

module mux2 (A, B, S, out);
  input [31:0]A;
  input [31:0]B;
  input S;
  output reg [31:0]out;
  
  always @ (A, B, S) begin
    out = 32'b0;
    if (S == 1'b0) out = A;
    else out = B;
  end
endmodule

module ALU (A, B, ALUOperation, zero, ALUResult);
  input [31:0]A;
  input [31:0]B;
  input [2:0]ALUOperation;
  output zero;
  output reg [31:0]ALUResult;
  assign zero = (ALUResult == 32'b0) ? 1'b1 : 1'b0;
  always @ (A or B or ALUOperation) begin
    case (ALUOperation)
      3'b000:  //AND
        ALUResult = A & B;
      3'b001: //OR
        ALUResult = A | B;
      3'b010:  //ADD
        ALUResult = A + B;
      3'b110:  //SUB
        ALUResult = A - B;
      3'b111: //SLT
        ALUResult = (A < B);
      default: ALUResult = A + B;
    endcase
  end
endmodule

module dataMemory (address, writeData, memRead, memWrite, clk, rst, readData);
  input [31:0]address;
  input [31:0]writeData;
  input memRead;
  input memWrite;
  input clk;
  input rst;
  output [31:0]readData;
  
  reg [31:0] memory[0:2047];
  always @(posedge clk) begin
    if (rst == 1'b1) $readmemb("dataMemory.txt",memory);
    else begin
      if (memWrite) begin
        memory[address] <= writeData; 
      end
    end
  end
  assign readData = memory[address];
endmodule

module PCReg (newPC, clk, rst, PC);
  input [31:0]newPC;
  input clk;
  input rst;
  output reg [31:0]PC;
  always @ (posedge clk) begin
    if (rst)  PC <= 32'b0;
    else PC <= newPC;
  end
endmodule

module instructionMemory (input [31:0]PC,input clk,input rst,output [31:0]instruction);
  reg [7:0] instructions[0:399];
  assign instruction = {instructions[PC],instructions[PC+2'b01],instructions[PC+2'b10],instructions[PC+2'b11]};
  always @(posedge clk)begin
    if (rst == 1'b1) $readmemb("instructions.txt",instructions);
  end
endmodule

module registerFile (input [4:0]readReg1,input [4:0]readReg2,input [4:0]writeReg,input [31:0]writeData,input regWrite,input clk,input rst,output [31:0]data1,output [31:0]data2);
  reg [31:0] R[0:31];
  assign data1 = R[readReg1];
  assign data2 = R[readReg2];
  always @(posedge clk)begin
    if (rst == 1'b1) R[0] <= 32'b0;
    else begin
      if (regWrite == 1'b1) R[writeReg] <= writeData;
    end
  end
endmodule

module adder32 (input [31:0]A,input [31:0]B,output [31:0]S);
  assign S = A + B;
endmodule

module shL2_26 (input [25:0]A, output [27:0]S);
  assign S = {A, 2'b00};
endmodule

module shL2_32 (input [31:0]A,output [31:0]S);
  assign S = {A[29:0], 2'b00};
endmodule


module test();
  reg clk,rst;
  MIPS mips(clk,rst);
  initial begin
    #80 #20 clk = 1'b0;
    #80 rst = 1'b1; #20 clk = 1'b1;
    #80 rst = 1'b0; #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
    #80 #20 clk = 1'b1;
    #80 #20 clk = 1'b0;
  end
endmodule
