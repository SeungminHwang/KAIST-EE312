module RISCV_TOP (
	//General Signals
	input wire CLK,
	input wire RSTn,

	//I-Memory Signals
	output wire I_MEM_CSN,
	input wire [31:0] I_MEM_DI,//input from IM
	output reg [11:0] I_MEM_ADDR,//in byte address

	//D-Memory Signals
	output wire D_MEM_CSN,
	input wire [31:0] D_MEM_DI,
	output wire [31:0] D_MEM_DOUT,
	output wire [11:0] D_MEM_ADDR,//in word address
	output wire D_MEM_WEN,
	output wire [3:0] D_MEM_BE,

	//RegFile Signals
	output wire RF_WE,
	output wire [4:0] RF_RA1,
	output wire [4:0] RF_RA2,
	output wire [4:0] RF_WA1,
	input wire [31:0] RF_RD1,
	input wire [31:0] RF_RD2,
	output wire [31:0] RF_WD,
	output wire HALT,                   // if set, terminate program
	output reg [31:0] NUM_INST,         // number of instruction completed
	output wire [31:0] OUTPUT_PORT      // equal RF_WD this port is used for test
	);

	assign OUTPUT_PORT = RF_WD;

	initial begin
		NUM_INST <= -5;//Check 
	end

	// Only allow for NUM_INST
	always @ (negedge CLK) begin
		if (RSTn) NUM_INST <= NUM_INST + 1;
	end

	// TODO: implement


    // Memory module synchronize
    assign I_MEM_CSN = ~RSTn;
    assign D_MEM_CSN = ~RSTn;


    // registers and wires
    wire stall;
    /*[Task 0] make a stall signal generator*/

    reg [11:0] PC;
    reg [11:0] nextPC;

    initial begin
        PC = 0;
    end


    always @ (posedge CLK) begin
		$display("IF_IR: %x, stall: %x, IMEMDI: %x, RSTn: %x, NUM_INST", IF_IR, stall, I_MEM_DI, RSTn, NUM_INST);
		$display("ID_WB_Dest: %x", ID_WB_Dest);
		$display("EXE_WB_Dest: %x, EXE_EXE_result: %x", EXE_WB_Dest, EXE_EXE_result);
		$display("MEM_WB_Dest: %x", MEM_WB_Dest);
		$display("------------------------");
        if (RSTn) begin
            if(~stall) begin
                PC <= nextPC;
                I_MEM_ADDR <= nextPC;
            end
        end
        else begin
            I_MEM_ADDR <= PC;
        end
    end


    // Stage 0: stall generator
    reg stall_r;
    assign stall = stall_r;
	initial begin
		stall_r = 1'b0;
	end
    always @ (*) begin
        stall_r = 1'b0;
		if(MEM_sigJAL | MEM_sigJALR | MEM_sigBRANCH | EXE_sigJAL | EXE_sigJALR | EXE_sigBRANCH | ID_sigJAL | ID_sigJALR | ID_sigBRANCH) begin
			stall_r = 1'b1;
		end
		if(sigJAL | sigJALR) begin // at ID stage -> Block IF
            stall_r = 1'b1;
        end
        if(IF_IR[19:15] != 0 & ((IF_IR[19:15] == ID_WB_Dest) | (IF_IR[19:15] == EXE_WB_Dest) | (IF_IR[19:15] == MEM_WB_Dest))) begin
            stall_r = 1'b1;
        end
        if(IF_IR[19:15] != 0 & ((IF_IR[24:20] == ID_WB_Dest) | (IF_IR[24:20] == EXE_WB_Dest) | (IF_IR[24:20] == MEM_WB_Dest))) begin
            stall_r = 1'b1;
        end
    end



    // Stage 1: IF

    // Pipeline IF/ID
    //// Pipeline member
    reg [31:0] IF_IR;
    reg [11:0] IF_nextPC;

    //// Update Pipeline
    always @ (posedge CLK) begin
        if(RSTn & (~stall)) begin
            IF_IR <= I_MEM_DI;
            IF_nextPC <= PC + 4; // Check
        end
    end


    // Stage 2: ID/RF
    //// ID member
    wire [6:0] opcode;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [4:0] rd;
	wire [2:0] funct3;
	wire [6:0] funct7;
	assign opcode = IF_IR[6:0];
	assign rs1 = IF_IR[19:15];
	assign rs2 = IF_IR[24:20];
	assign rd = IF_IR[11:7];
	assign funct3 = IF_IR[14:12];
	assign funct7 = IF_IR[31:25];

    //////HALT
    reg HALT_r;
    assign HALT = HALT_r;

    ////// imm field
    wire [31:0] immI, immS, immB, immJ, immU;
    reg [31:0] immI_r, immS_r, immB_r, immJ_r, immU_r;
	assign immI = immI_r, immS = immS_r, immB = immB_r, immJ = immJ_r, immU = immU_r;

    ////// Operands
    wire [31:0] op1, op2;
    reg [31:0] op1_r, op2_r;
    assign op1 = op1_r, op2 = op2_r;

    ////// Signal generating
    wire sigOpIMM, sigOP, sigJAL, sigJALR, sigBRANCH, sigLOAD, sigSTORE;
	assign sigOpIMM = (opcode == 7'b0010011); // I type
	assign sigOP = (opcode == 7'b0110011); //R type
	assign sigJAL = (opcode == 7'b1101111); // J type
	assign sigJALR = ( opcode == 7'b1100111 ); // Itype
	assign sigBRANCH = (opcode == 7'b1100011); // B type
	assign sigLOAD = (opcode == 7'b0000011); // I type
	assign sigSTORE = (opcode == 7'b0100011); // S type

    wire sigALUSrc, sigMemToReg;
	assign sigALUSrc =  (sigOP) | (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate
	assign sigMemToReg =  sigLOAD;

    always @ (*) begin
        //regInUse[rd] = 1;// reg dest on!

		// immediate filed generator
		if(IF_IR[31] == 1'b1) begin
			immI_r = {21'b111111111111111111111, IF_IR[30:25], IF_IR[24:21], IF_IR[20]};
			immS_r = {20'b11111111111111111111,IF_IR[31], IF_IR[30:25], IF_IR[11:8], IF_IR[7]};
			immB_r = {19'b1111111111111111111, IF_IR[31], IF_IR[7], IF_IR[30:25], IF_IR[11:8], 1'b0};
			immJ_r = {11'b11111111111, IF_IR[31], IF_IR[19:12], IF_IR[20], IF_IR[30:25], IF_IR[24:21], 1'b0};
		end
		else begin
			immI_r = {21'b000000000000000000000, IF_IR[30:25], IF_IR[24:21], IF_IR[20]};
			immS_r = {20'b00000000000000000000,IF_IR[31], IF_IR[30:25], IF_IR[11:8], IF_IR[7]};
			immB_r = {19'b0000000000000000000, IF_IR[31], IF_IR[7], IF_IR[30:25], IF_IR[11:8], 1'b0};
			immJ_r = {11'b00000000000, IF_IR[31], IF_IR[19:12], IF_IR[20], IF_IR[30:25], IF_IR[24:21], 1'b0};
		end

		//HALT
		if((IF_IR == 32'h00008067) & (RF_RD1 == 32'h0000000c)) begin
			HALT_r = 1;
		end

		//operands
		op1_r = RF_RD1;
		if(sigOP)	 op2_r = RF_RD2;
		else if(sigOpIMM) op2_r = immI;
    end

    

    // Pipeline ID/EXE
    //// Pipeline member
    ////// About WB
    reg [4:0] ID_WB_Dest; // Write back destination, rd
    reg ID_RF_WE; // Register File write enable
    reg ID_sigMemToReg; // 1 -> Mem to rd, 0 -> reg to rd

    ////// About MEM
    reg ID_sigMemWrite; // data memory write enable
    reg ID_sigMemRead; // data memory read enable

    ////// About EXE
    reg [11:0] ID_nextPC;
    reg [31:0] ID_OP1, ID_OP2; // operands for ALU
	reg [2:0] ID_funct3;// = IF_IR[14:12];
	reg [6:0] ID_funct7;// = IF_IR[31:25];

    reg ID_sigBRANCH, ID_sigLOAD, ID_sigSTORE, ID_sigJAL, ID_sigJALR;

	reg [31:0] ID_immI, ID_immS, ID_immB, ID_immJ, ID_immU; // imm fields


    //// Update Pipeline
    always @ (posedge CLK) begin
        if(RSTn) begin
            ID_WB_Dest <= rd;
            ID_RF_WE <= (sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM); // instructions that includes Reg file Write Back
            ID_sigMemToReg <= sigLOAD;
            
            ID_sigMemWrite <= sigSTORE; //Check
            ID_sigMemRead <= sigLOAD; //Check

            ID_nextPC <= IF_nextPC;
            ID_OP1 <= op1;
            ID_OP2 <= op2;
            ID_funct3 <= funct3;
            ID_funct7 <= funct7;

            ID_sigBRANCH <= sigBRANCH;
            ID_sigLOAD <= sigLOAD;
            ID_sigSTORE <= sigSTORE;
            ID_sigJAL <= sigJAL;
            ID_sigJALR <= sigJALR;

            ID_immI <= immI;
            ID_immS <= immS;
            ID_immB <= immB;
            ID_immJ <= immJ;
            ID_immU <= immU;
        end
    end

    // Stage 3: EXE
    //// EXE member
    wire [31:0] ALUresult;
    wire [2:0] op;
    wire [6:0] subop;
    wire [31:0] aluOp1;
    wire [31:0] aluOp2;
    assign op = ID_funct3, subop = ID_funct7, aluOp1 = ID_OP1, aluOp2 = ID_OP2;

    wire bcond;// Check
    reg bcond_r;
    assign bcond = bcond_r;

    wire memAddr; // data memory address
    reg memAddr_r;
    assign memAddr = memAddr_r;

    reg [31:0] jmpResult_r;//temp
    reg [31:0] jmpPC_r; // jump PC register

    //// for OPIMM and OP
    ALU ALU(.activate(1'b1), .op(op), .subop(subop), .op1(aluOp1), .op2(aluOp2), .res(ALUresult));

    //// for jump and branch
    reg [31:0] temp;
    always @ (*) begin
        if(ID_sigBRANCH) begin // for branch
            case(ID_funct3)
                3'b000: bcond_r = (ID_OP1 == ID_OP2);//BEQ
                3'b010: bcond_r = (ID_OP1 != ID_OP2);//BNE
                3'b100: bcond_r = ($signed(ID_OP1) < $signed(ID_OP2));//BLT
                3'b101: bcond_r = ($signed(ID_OP1) >= $signed(ID_OP2));//BGE
                3'b110: bcond_r = (ID_OP1 < ID_OP2);
                3'b111: bcond_r = (ID_OP1 >= ID_OP2);
            endcase
            temp = immB + ID_nextPC - 4;
            jmpResult_r = temp[11:0];
        end
        if(ID_sigLOAD) begin
            memAddr_r = ID_OP1 + ID_immI;//Check
            jmpResult_r = ID_nextPC;
        end
        if(ID_sigSTORE) begin
            memAddr_r = ID_OP1 + ID_immS;//Check
            jmpResult_r = ID_nextPC;
        end
        if(ID_sigJAL) begin
            jmpPC_r = (ID_immJ + ID_nextPC - 4) & 12'hFFF;//Check: Weird nxtPC -4....;;
            jmpResult_r = ID_nextPC;
        end
        if(ID_sigJALR) begin
            jmpPC_r = ID_OP1 & 12'hFFF;
            jmpResult_r = ((ID_OP1 + ID_immI) >> 1) << 1;
        end
    end

    // Pipeline EXE/MEM
    //// Pipeline member
    ////// About WB
    reg [4:0] EXE_WB_Dest;
    reg EXE_RF_WE;
    reg EXE_sigMemToReg;
    reg EXE_EXE_result;
    reg EXE_nextPC; // next PC for jump and branch

    reg EXE_sigBRANCH, EXE_sigJAL, EXE_sigJALR, EXE_bcond;

    ////// About MEM
    reg EXE_sigMemRead; // ID_sigMemWrite;
    reg EXE_sigMemWrite; // ID_sigMemWrite;
    reg [11:0] EXE_MemAddr; // memory module address
    reg [31:0] EXE_WriteData; // memory module data input; RF_RD2 넣으면 될듯
    reg [3:0] EXE_funct3;// *B, *L, *W

    //any other signals?

    //// Update Pipeline 
    always @ (posedge CLK) begin
        if(RSTn) begin
            EXE_WB_Dest <= ID_WB_Dest;
            EXE_RF_WE <= ID_RF_WE;
            EXE_sigMemToReg <= ID_sigMemToReg;
            //EXE_EXE_result <=
            if(ID_sigJAL | ID_sigJALR) begin // if jump or branch, then change the nextPC
                EXE_nextPC <= jmpPC_r;
                EXE_EXE_result <= jmpResult_r; // special result;
            end
            else if (ID_sigBRANCH & bcond) begin
                EXE_nextPC <= jmpPC_r;
                EXE_EXE_result <= jmpResult_r; // special result;
            end
            else begin 
                EXE_nextPC <= ID_nextPC;
                EXE_EXE_result <= ALUresult; // otherwise, ALU result;
            end

            EXE_sigBRANCH <= ID_sigBRANCH;
            EXE_sigJAL <= ID_sigJAL;
            EXE_sigJALR <= ID_sigJALR;
            EXE_bcond <= bcond;

            EXE_sigMemRead <= ID_sigMemRead;
            EXE_sigMemWrite <= ID_sigMemWrite;
            EXE_MemAddr <= memAddr;
            EXE_WriteData <= ID_OP2;//Values that will be stored in data mem.
            EXE_funct3 <= ID_funct3;

			if(stall) begin
				ID_WB_Dest <= 0;
				ID_RF_WE <= 0;
				ID_sigMemToReg <= 0;

				ID_sigMemWrite <= 0;
				ID_sigMemRead <= 0;
				
				ID_nextPC <= 0;
				ID_OP1 <= 0;
				ID_OP2 <= 0;
				ID_funct3 <=0;
				ID_funct7 <= 0;

				ID_sigBRANCH <= 0;
				ID_sigLOAD <= 0;
				ID_sigSTORE <= 0;
				ID_sigJAL <= 0;
				ID_sigJALR <= 0;

				ID_immI <= 0;
				ID_immS <= 0;
				ID_immB <= 0;
				ID_immJ <= 0;
				ID_immU <= 0;
			end
        end
    end
    

    // Stage 4: MEM
    //// MEM members
    reg [3:0] BE_r;

    wire memOutput;
    reg memOutput_r;
    assign memOutput = memOutput_r; // data from data mem
    
    
    assign D_MEM_WEN = ~(EXE_sigMemWrite);
    assign D_MEM_ADDR = EXE_MemAddr;
    assign D_MEM_DOUT = EXE_WriteData;

    always @ (*) begin // memory output forming
		case(EXE_funct3[1:0])
			2'b00: BE_r = 4'b0001; //*B
			2'b01: BE_r = 4'b0011; //*H
			2'b10: BE_r = 4'b1111; //*W
		endcase
		if(EXE_sigMemRead) begin
			//memOutput_r = D_MEM_DI;
			if(EXE_funct3 == 3'b000) begin // lb
				if(D_MEM_DI[7] == 1'b1) begin
					memOutput_r = {24'b111111111111111111111111, D_MEM_DI[7:0]};
				end
				else begin
					memOutput_r = D_MEM_DI&8'hFF;
				end
			end
			if(EXE_funct3 == 3'b001) begin // lh
				//memOutput_r = D_MEM_DI & 16'hFFFF;
				if(D_MEM_DI[15] == 1'b1) begin
					memOutput_r = {16'b1111111111111111, D_MEM_DI[15:0]};
				end
				else begin
					memOutput_r = {16'b0, D_MEM_DI[15:0]};
				end
			end
			if(EXE_funct3 == 3'b100) begin // lbu
				memOutput_r = D_MEM_DI& 8'hFF;
			end
			if(EXE_funct3 == 3'b101) begin //lhu
				memOutput_r = D_MEM_DI & 16'hFFFF;
			end
		end
	end


    // Pipeline MEM/WB
    //// Pipeline members

    reg [4:0] MEM_WB_Dest;
    reg MEM_RF_WE;
    reg MEM_sigMemToReg;
    reg [31:0] MEM_EXE_result;
    reg [31:0] MEM_memOutput;
    reg [11:0] MEM_nextPC;

    reg MEM_sigBRANCH, MEM_sigJAL, MEM_sigJALR, MEM_bcond;


    //// Update Pipeline
    always @ (posedge CLK) begin
        if(RSTn) begin
            MEM_WB_Dest <= EXE_WB_Dest;
            MEM_RF_WE <= EXE_RF_WE;
            MEM_sigMemToReg <= EXE_sigMemToReg;
            MEM_EXE_result <= EXE_EXE_result;
            MEM_memOutput <= memOutput;
            MEM_nextPC <= EXE_nextPC;

            MEM_sigBRANCH <= EXE_sigBRANCH;
            MEM_sigJAL <= EXE_sigJAL;
            MEM_sigJALR <= EXE_sigJALR;
            MEM_bcond <= EXE_bcond;
        end
    end
    

    // Stage 5: WB
    reg [31:0] WD_r;
    assign RF_WD = WD_r;
    assign RF_WE = MEM_RF_WE;
    assign RF_WA1 = MEM_WB_Dest;

    always @ (*) begin
        if(MEM_sigMemToReg) begin // Load!
            WD_r = MEM_memOutput;
        end
        else begin
            WD_r = MEM_EXE_result;
        end
    end

    always @ (*) begin // PC
        if(MEM_sigJAL | MEM_sigJALR | (MEM_sigBRANCH & MEM_bcond)) begin
            nextPC = MEM_nextPC;
        end
        if(~stall)  nextPC = PC + 4;
        else    nextPC = PC; // If there is stall, maintain PC
    end


endmodule