//MemToReg = DataRegSelect

module ALUControl (ALUOp, func, ALUOperation);
  input [1:0]ALUOp;
  input [5:0]func;
  output reg [2:0]ALUOperation;
  always @(ALUOp or func) begin
    case (ALUOp)
      2'b00: ALUOperation = 3'b010;  //OPC: Lw and Sw and Addi
                                  //ALU Operation: Add
      2'b01: ALUOperation = 3'b110;  //OPC: Beq
                                  //ALU Operation: Sub
      2'b10: case (func) //R-Type
            6'b100000: ALUOperation = 3'b010; //Add
            6'b100010: ALUOperation = 3'b110; //Sub
            6'b100100: ALUOperation = 3'b000; //And
            6'b100101: ALUOperation = 3'b001; //Or
            6'b101010: ALUOperation = 3'b111; //Slt
            default: ALUOperation = 3'b010;
          endcase
      2'b11: ALUOperation = 3'b000; //OPC: Andi
                                 //ALU Operation: And
      default: ALUOperation = 3'b010;
    endcase
  end
endmodule

module Control (OPC, RegDst, ALUSrc, MemToReg, RegWrite, MemRead, MemWrite, Branch, ALUOp);
  input [5:0]OPC;
  output reg [1:0]RegDst;
  output reg ALUSrc;
  output reg [1:0]MemToReg;
  output reg RegWrite, MemRead, MemWrite;
  output reg [2:0]Branch;
  output reg [1:0]ALUOp;
  always @(OPC) begin
    case (OPC)
      6'b000000: begin //R-Type
        RegDst = 2'b01;
        ALUSrc = 1'b0;
        MemToReg = 2'b00;
        RegWrite = 1'b1;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b100;  //Only for Jr
        ALUOp = 2'b10;
      end
      6'b000010: begin //J
        RegWrite = 1'b0;
        MemRead = 2'b0;
        MemWrite = 1'b0;
        Branch = 3'b011;
      end
      6'b000001: begin //Jal
        RegDst = 2'b10;
        MemToReg = 2'b10;
        RegWrite = 1'b1;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b011;
      end
      6'b001000: begin //Addi
        RegDst = 2'b00;
        ALUSrc = 1'b1;
        MemToReg = 2'b00;
        RegWrite = 1'b1;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b000;
        ALUOp = 2'b00;
      end
      6'b001100: begin //Andi
        RegDst = 2'b00;
        ALUSrc = 1'b1;
        MemToReg = 2'b00;
        RegWrite = 1'b1;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b000;
        ALUOp = 2'b11;
      end
      6'b100011: begin //Lw
        RegDst = 2'b00;
        ALUSrc = 1'b1;
        MemToReg = 2'b01;
        RegWrite = 1'b1;
        MemRead = 1'b1;
        MemWrite = 1'b0;
        Branch = 3'b000;
        ALUOp = 2'b00;
      end
      6'b101011: begin //Sw
        ALUSrc = 1'b1;
        RegWrite = 1'b0;
        MemRead = 1'b0;
        MemWrite = 1'b1;
        Branch = 3'b000;
        ALUOp = 2'b00;
      end
      6'b000100: begin //Beq
        ALUSrc = 1'b0;
        RegWrite = 1'b0;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b001;
        ALUOp = 2'b01;
      end
      6'b000101: begin //Bne
        ALUSrc = 1'b0;
        RegWrite = 1'b0;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 3'b010;
        ALUOp = 2'b01;
      end
    endcase
  end
endmodule

module ControlFlow (Branch, Zero, func, PCSrc);
  input [2:0]Branch;
  input Zero;
  input [5:0]func; 
  output reg [1:0]PCSrc;
  always @(Branch or Zero or func) begin
    case (Branch)
      3'b000: PCSrc = 2'b01; //Not a Control Flow Instruction
      3'b001: begin  //Beq
        if (Zero)
          PCSrc = 2'b00;
        else
          PCSrc = 2'b01;
      end
      3'b010: begin  //Bne
        if (Zero == 1'b0)
          PCSrc = 2'b00;
        else
          PCSrc = 2'b01;
      end
      3'b011: PCSrc = 2'b11; //J and Jal
      3'b100: begin  //Jr
        if (func == 6'b001000)
          PCSrc = 2'b10;
        else
          PCSrc = 2'b01;
      end
    endcase
  end
endmodule

module ControlUnit (OPC, func, Zero, RegDst, ALUSrc, MemToReg, RegWrite, MemRead, MemWrite, ALUOperation, PCSrc);
  input [5:0]OPC;
  input [5:0]func;
  input Zero;
  output [1:0]RegDst;
  output ALUSrc;
  output [1:0]MemToReg; 
  output RegWrite, MemRead, MemWrite;
  output [2:0]ALUOperation;
  output [1:0]PCSrc;
  wire [2:0]Branch;
  wire [1:0]ALUOp;
  Control C0 (OPC, RegDst, ALUSrc, MemToReg, RegWrite, MemRead, MemWrite, Branch, ALUOp);
  ALUControl C1 (ALUOp, func, ALUOperation);
  ControlFlow C2 (Branch, Zero, func, PCSrc);
endmodule

