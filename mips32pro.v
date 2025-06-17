module pipe_MIPS32(clk1,clk2);
input clk1,clk2;
reg[31:0] PC, IF_ID_IR, IF_ID_NPC;
reg[31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_IMM;
reg[2:0] ID_EX_TYPE,EX_MEM_TYPE,MEM_WB_TYPE;
reg[31:0] EX_MEM_IR, EX_MEM_ALUOUT,EX_MEM_B;
reg[31:0] MEM_WB_IR,MEM_WB_ALUOUT,MEM_WB_LMD;
reg EX_MEM_cond;
reg[31:0] Reg [0:31];// registerbank (32x32)
reg [31:0] Mem [0:1023]; //1024 x 32 memory

parameter ADD=6'b000000, SUB =6'b000001,AND=6'b000010 ,OR=6'b000011,
           SLT=6'b000100, MUL=6'b000101,HLT=6'b111111,LW=6'b001000,
           SW=6'b001001,ADDI=6'b001010, SUBI=6'b001011,SLTI=6'b001100,
           BNEQZ=6'b001101, BEQZ=6'b001110;
parameter  RR_ALU=3'b000, RM_ALU = 3'b001, LOAD=3'b010, STORE=3'b011,BRANCH=3'b100, HALT=3'b101;
reg HALTED;
//set after HLTinstruction is completed(in WB stage)
reg TAKEN_BRANCH;
// required to disable instructions after branch
always@(posedge clk1)
if(HALTED ==0)
begin
    if(((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond == 1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
    begin
        IF_ID_IR <= #2 Mem[EX_MEM_ALUOUT];
        TAKEN_BRANCH <= #2 1'b1;
        IF_ID_NPC <= #2 EX_MEM_ALUOUT + 1;
        PC  <= #2 EX_MEM_ALUOUT +1 ;
            $display("[%0t] IF Stage: PC = %h, Instruction = %h", $time, PC, Mem[PC]);
    end
    else
    begin 
        IF_ID_IR <= #2 Mem[PC];
        IF_ID_NPC <= #2 PC + 1;
        PC <= #2 PC + 1;


    end
end
always@(posedge clk2)  //ID Stage
if(HALTED == 0)
    begin
       $display("[%0t] ID Stage: IR = %h, NPC = %h", $time, IF_ID_IR, IF_ID_NPC);
    $display("            Read Reg: rs=%d (A=%h), rt=%d (B=%h)", 
             IF_ID_IR[25:21], ID_EX_A, IF_ID_IR[20:16], ID_EX_B);
    if(IF_ID_IR[25:21] == 5'b00000)  
      ID_EX_A <= 0;
    else 
      ID_EX_A <= #2 Reg[IF_ID_IR[25:21]]; //rs
     if(IF_ID_IR[20:16] == 5'b00000) 
      ID_EX_B <= 0;
     else
      begin
      ID_EX_B  <=  #2 Reg[IF_ID_IR[20:16]]; //rt
      ID_EX_NPC <= #2 IF_ID_NPC;
      ID_EX_IR  <= #2 IF_ID_IR;
      ID_EX_IMM <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};// sign extension
      end
    
      case (IF_ID_IR[31:26])
        ADD,SUB,AND,OR,SLT,MUL: ID_EX_TYPE <= #2 RR_ALU;
        ADDI,SUBI,SLTI:         ID_EX_TYPE <= #2 RM_ALU;
        LW:                     ID_EX_TYPE <= #2 LOAD;
        SW:                     ID_EX_TYPE <= #2 STORE;
        BNEQZ,BEQZ:             ID_EX_TYPE <= #2 BRANCH;
        HLT:                    ID_EX_TYPE <= #2 HALT;
        default:                ID_EX_TYPE <= #2 HALT;
// invalid opcode
      endcase
    end

always@(posedge clk1)         // EX STAGE
if(HALTED == 0)
begin 
  $display("[%0t] EX Stage: Type=%b, A=%h, B=%h, Imm=%h", 
             $time, ID_EX_TYPE, ID_EX_A, ID_EX_B, ID_EX_IMM);
    EX_MEM_TYPE <= #2 ID_EX_TYPE;
    EX_MEM_IR <= #2 ID_EX_IR;
    TAKEN_BRANCH <= #2 0;
    case (ID_EX_TYPE)
    RR_ALU: begin 
        case(ID_EX_IR[31:26]) // OP CODE
             ADD: EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_B;
             SUB: EX_MEM_ALUOUT <= #2 ID_EX_A - ID_EX_B;
             AND: EX_MEM_ALUOUT <= #2 ID_EX_A & ID_EX_B;
             OR:  EX_MEM_ALUOUT <= #2 ID_EX_A | ID_EX_B;
             SLT: EX_MEM_ALUOUT <= #2 ID_EX_A < ID_EX_B;
             MUL: EX_MEM_ALUOUT <= #2 ID_EX_A * ID_EX_B;
             default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx;
        endcase
    end
    RM_ALU: begin
        case(ID_EX_IR[31:26]) // OP CODE
        ADDI: EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
        SUBI: EX_MEM_ALUOUT <= #2 ID_EX_A - ID_EX_IMM;
        SLTI: EX_MEM_ALUOUT <= #2 ID_EX_A < ID_EX_IMM;
        default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx;
        endcase
    end
    LOAD,STORE:
    begin
        EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
        EX_MEM_B      <= #2 ID_EX_B;
    end
    BRANCH: begin
        EX_MEM_ALUOUT <= #2 ID_EX_NPC + ID_EX_IMM;
        EX_MEM_cond   <= #2 (ID_EX_A == 0);
    end
 endcase
end
always@(posedge clk2)  // MEM stage
if(HALTED == 0)
begin 
    MEM_WB_TYPE <= EX_MEM_TYPE;
    MEM_WB_IR <= #2 EX_MEM_IR;
    case(EX_MEM_TYPE)
    RR_ALU,RM_ALU: MEM_WB_ALUOUT <= #2 EX_MEM_ALUOUT;//CHUDALI
    LOAD:  MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOUT];
    STORE: if(TAKEN_BRANCH == 0)   // DISABLE WRITE
    Mem[EX_MEM_ALUOUT] <= #2 EX_MEM_B;
    endcase            

end
always@(posedge clk1)      // WB stage
begin
    if(TAKEN_BRANCH == 0) // disable write if branch 
    case(MEM_WB_TYPE)
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOUT; // "rd"
    RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOUT; // "rt"
    LOAD:   Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; //"rt"
    HALT:   HALTED <= #2 1'b1;
    endcase
end
// ... (all your pipeline stages remain unchanged) ...

// Add this JUST BEFORE endmodule:
always @(posedge clk1) begin
    $display("=== CYCLE %0d ===", $time/100);
    $display("IF_ID:  IR=%h, NPC=%h", IF_ID_IR, IF_ID_NPC);
    $display("ID_EX:  IR=%h, A=%h, B=%h, Imm=%h, Type=%b", 
             ID_EX_IR, ID_EX_A, ID_EX_B, ID_EX_IMM, ID_EX_TYPE);
    $display("EX_MEM: IR=%h, ALUOut=%h, B=%h, cond=%b, Type=%b", 
             EX_MEM_IR, EX_MEM_ALUOUT, EX_MEM_B, EX_MEM_cond, EX_MEM_TYPE);
    $display("MEM_WB: IR=%h, %s=%h, Type=%b", 
             MEM_WB_IR, 
             (MEM_WB_TYPE == LOAD) ? "LMD" : "ALUOut",
             (MEM_WB_TYPE == LOAD) ? MEM_WB_LMD : MEM_WB_ALUOUT,
             MEM_WB_TYPE);
    $display("----------------------------------------");
end


endmodule
