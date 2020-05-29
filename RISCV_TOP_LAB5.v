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
		NUM_INST <= 0;
	end

	reg Complete;
	// Only allow for NUM_INST
	always @ (negedge CLK) begin
		if (RSTn&Complete) NUM_INST <= NUM_INST + 1;
	end

	// TODO: implement

	// PIPE
	reg[11:0] PC, nextPC, PC_ID, PC_EX, PC_MEM, PC_WB, nextPC_ID, nextPC_EX, nextPC_MEM, nextPC_WB;
	reg[31:0] IR, IR_ID, IR_EX, IR_MEM, IR_WB, nextIR_ID, nextIR_EX, nextIR_MEM, nextIR_WB;
	reg[31:0] A_ID, A_EX, A_MEM, B_ID, B_EX, B_MEM;
	reg[31:0] WD_MEM, WD_WB;

	// Harzard Control
	reg[4:0] RD_ID, RD_EX, RD_MEM, RD_WB;
	reg[4:0] RS1, RS2;
	reg [2:0] Counter, nextCounter;

	// Signal
	reg[4:0] SigStage = 5'b00000;
	reg[4:0] nextSigStage;
	reg IRWrite, PCWrite, IDWrite, Gen_Imm, ALUOp, IorD, RegWrite, LocalJump, regHALT, PCSource, PCBranch;

	// Register
	reg[4:0] rd, rs1, rs2;
	reg[31:0] immI_ID, immI_EX, immJ_ID, immJ_EX, immS_ID, immS_EX, immB_ID, immB_EX, ALUOut, ALUOut_MEM, ALUOut_WB, ALUOut_temp, result, regWD, regMemOutput_MEM, regMemOutput_WB, oprnd1, oprnd2;
	reg[3:0] regBE, regBE_MEM;
	reg[11:0] address;
	reg SAVOR;

	initial begin
		Counter <= 1;
		PC <= 0;
		nextPC <= 0;
	end

	// Update
	always @(posedge CLK) begin
		if (RSTn) begin
			if(PCWrite) begin
				PC <= nextPC;
				PC_ID <= nextPC_ID;
				PC_EX <= nextPC_EX;
				PC_MEM <= nextPC_MEM;
				PC_WB <= nextPC_WB;
				I_MEM_ADDR <= nextPC;
			end
			else begin
				I_MEM_ADDR <= PC;
			end
			IR_ID <= nextIR_ID;
			IR_EX <= nextIR_EX;
			IR_MEM <= nextIR_MEM;
			IR_WB <= nextIR_WB;
			SigStage <= nextSigStage;
			regMemOutput_WB <= regMemOutput_MEM;
			regBE <= regBE_MEM;
			immI_EX <= immI_ID;
			immJ_EX <= immJ_ID;
			immS_EX <= immS_ID;
			immB_EX <= immB_ID;
			ALUOut_MEM <= ALUOut;
			ALUOut_WB <= ALUOut_temp
		end
		else begin
			I_MEM_ADDR <= PC;
		end
	end


	// PC State
	always @(*) begin
		nextPC_ID = PC;
		nextPC_EX = PC_ID;
		nextPC_MEM = PC_EX;
		nextPC_WB = PC_WB;
		nextIR_ID = IR;
		nextIR_EX = IR_ID;
		nextIR_MEM = IR_EX;
		nextIR_WB = IR_MEM;
		ALUOut_temp = ALUOut_MEM;
	end

	// Control State
	always @(*) begin
		if(SigStage[0]) begin //IF stage
			IRWrite = 1;
		end
		else begin
			IRWrite = 0;
		end
		if(SigStage[1]) begin //ID stage
			IDWrite = 1;
			Gen_Imm = 1;
		end
		else begin
			IDWrite = 0;
			Gen_Imm = 0;
		end
		if(SigStage[2]) begin //EX stage
			ALUOp = 1;
		end
		else begin 
			ALUOp = 0;
		end
		if(SigStage[3]) begin //MEM stage
			IorD = 1;
		end
		else begin
			IorD = 0;
		end
		if(SigStage[4]) begin //WB stage
			RegWrite = 1;
			Complete = 1;
		end
		else begin
			RegWrite = 0;
			Complete = 0;
		end
	end

	//Stage State
	always @(*) begin
		LocalJump = 0;
		if(I_MEM_DI[19:15]==IR_ID[11:7]) begin // dist(X,Y) == 1
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[19:15]==IR_EX[11:7]) begin // dist(X,Y) == 2
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[19:15]==IR_MEM[11:7]) begin // dist(X,Y) == 3
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[19:15]==IR_WB[11:7]) begin // dist(X,Y) == 4
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[24:20]==IR_ID[11:7]) begin // dist(X,Y) == 1
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[24:20]==IR_EX[11:7]) begin // dist(X,Y) == 2
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[24:20]==IR_MEM[11:7]) begin //dist(X,Y) == 3
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(I_MEM_DI[24:20]==IR_WB[11:7]) begin //dist(X,Y) == 4
			case(Counter) 
				3'b001 : begin
					nextSigStage = 5'b11100;
					nextCounter = 2;
				end
				3'b010 : begin
					nextSigStage = 5'b11000;
					nextCounter = 3;
				end
				3'b011 : begin
					nextSigStage = 5'b10000;
					nextCounter = 4; 
				end
				3'b100 : begin
					nextSigStage = 5'b00011;
					nextCounter = 1;
				end
			endcase
		end
		else if(IR[6:0]==7'b1101111) begin  //opcode[nextIR] == Jump
			case(Counter) 
				2'b01 : begin
					nextSigStage = 5'b11110;
					nextCounter = 2;
				end
				2'b10 : begin
					nextSigStage = 5'b11100;
					nextCounter = 3;
				end
				2'b11 : begin
					nextSigStage = 5'b11001;
					nextCounter = 1;
					LocalJump = 1;
				end
			endcase
		end
		else if(IR[6:0]==7'b1100111) begin //opcode[nextIR] == JALR
			case(Counter) 
				2'b01 : begin
					nextSigStage = 5'b11110;
					nextCounter = 2;
				end
				2'b10 : begin
					nextSigStage = 5'b11100;
					nextCounter = 3;
				end
				2'b11 : begin
					nextSigStage = 5'b11001;
					nextCounter = 1;
					LocalJump = 1;
				end
			endcase
		end
		else if(IR[6:0]==7'b1100011) begin //opcode[nextIR] == BRANCH
			case(Counter) 
				2'b01 : begin
					nextSigStage = 5'b11110;
					nextCounter = 2;
				end
				2'b10 : begin
					SigStage = 5'b11100;
					nextCounter = 3;
				end
				2'b11 : begin
					nextSigStage = 5'b11001;
					nextCounter = 1; 
					LocalJump = 1;
				end
			endcase
		end
		else begin
			case(SigStage)
				5'b00001 : nextSigStage = 5'b00011;
				5'b00011 : nextSigStage = 5'b00111;
				5'b00111 : nextSigStage = 5'b01111;
				5'b01111 : nextSigStage = 5'b11111;
				5'b11111 : nextSigStage = 5'b11111;
				5'b11001 : nextSigStage = 5'b10011;
				5'b10011 : nextSigStage = 5'b00111;
				default : nextSigStage = 5'b00001;
			endcase
		end
		if(nextSigStage[0]) PCWrite = 1;
		else PCWrite = 0;
	end

	// For WB Stage 
	assign RF_WE = SigStage[4]&(( IR_MEM[6:0] == 7'b1101111 )| ( IR_MEM[6:0] == 7'b1100111 ) |( IR_MEM[6:0] == 7'b0000011 ) |( IR_MEM[6:0] == 7'b0110011 ) | ( IR_MEM[6:0] == 7'b0010011 ));

	// Terminate the Program __ Signal
	assign HALT = regHALT;
	always @ (*) begin
		if((I_MEM_DI == 32'h00008067) & (RF_RD1 == 32'h0000000c)) begin
			regHALT = 1;
		end
	end

	//1. Instruction Fetch 
	always @(*) begin
		if(IRWrite) begin
			IR = I_MEM_DI; // copy input to the Instruction Regsiter
			nextPC = PC + 4; // If the next instruction doesn't jump, branch,then nextPC = PC+4
		end
	end

	//2. Instruction Decode

	// Make Immediate Field
	always @(*) begin
		if(Gen_Imm)begin
			if(IR_ID[31] == 1'b1) begin
				immI_ID = {20'b11111111111111111111, IR_ID[31], IR_ID[30:25], IR_ID[24:21], IR_ID[20]};
				immS_ID = {20'b11111111111111111111,IR_ID[31], IR_ID[30:25], IR_ID[11:8], IR_ID[7]};
				immB_ID = {19'b1111111111111111111, IR_ID[31], IR_ID[7], IR_ID[30:25], IR_ID[11:8], 1'b0};
				immJ_ID = {11'b11111111111, IR_ID[31], IR_ID[19:12], IR_ID[20], IR_ID[30:25], IR_ID[24:21], 1'b0};
			end
			else begin
				immI_ID = {20'b00000000000000000000, IR_ID[31], IR_ID[30:25], IR_ID[24:21], IR_ID[20]};
				immS_ID = {20'b00000000000000000000,IR_ID[31], IR_ID[30:25], IR_ID[11:8], IR_ID[7]};
				immB_ID = {19'b0000000000000000000, IR_ID[31], IR_ID[7], IR_ID[30:25], IR_ID[11:8], 1'b0};
				immJ_ID = {11'b00000000000, IR_ID[31], IR_ID[19:12], IR_ID[20], IR_ID[30:25], IR_ID[24:21], 1'b0};
			end
		end
	end

	//  Processing Instruction

	assign RF_RD1 = rs1;
	assign RF_RD2 = rs2;
	assign RF_WA1 = rd;

	always @(*) begin
		if(IDWrite)begin
			rs1 = IR_ID[19:15];
			rs2 = IR_ID[24:20];
			rd = IR_ID[11:7];
		end
	end

	// Get Register Data (at ID stage)
	always @(*) begin
		if(IDWrite) begin
			A_ID = RF_RD1;
			B_ID = RF_RD2;
		end
	end

	// 3. Execution Stage
	always @(*) begin
		if(ALUOp) begin
			oprnd1 = A_EX;
			oprnd2 = B_EX;	
			if(IR_EX[6:0] == 7'b0110011) begin
				case(IR_EX[14:12])
					3'b000: begin
						if(IR_EX[31:25] == 7'b0000000) begin // ADD
							result = oprnd1+oprnd2;
						end
						if(IR_EX[31:25] == 7'b0100000) begin // SUB
							result = oprnd1-oprnd2;
						end
					end
					3'b001: begin // SLL
						result = oprnd1 << oprnd2[4:0];
					end
					3'b010: begin // SLT
						result = $signed(oprnd1) < $signed(oprnd2);
					end
					3'b011: begin // SLTU
						result = oprnd1 < oprnd2;
					end
					3'b100: begin // XOR
						result = oprnd1 ^ oprnd2;
					end
					3'b101: begin // SRL, SRA
						if(IR_EX[31:25] == 7'b0000000) begin // SRL
							result = oprnd1 >> oprnd2[4:0];
						end
						if(IR_EX[31:25] == 7'b0100000) begin // SRA
							result = (oprnd1 >> oprnd2[4:0]) | (oprnd1[31] << 31); //please modify
						end
					end
					3'b110: begin // OR
						result = oprnd1 | oprnd2;
					end
					3'b111: begin // AND
						result = oprnd1 & oprnd2;
					end
				endcase
			end
			else if(IR_EX[6:0] == 7'b0000011) begin // Load
				result = oprnd1 + immI_EX;
			end
			else if (IR_EX[6:0] == 7'b0100011) begin // Store
				result = oprnd1 + immS_EX;
			end
			else if(IR_EX[6:0] == 7'b1100111) begin // JALR
				result = ((oprnd1 + immI_EX)>>1)<<1;
				PCSource = 2;
			end
			else if(IR_EX[6:0] == 7'b1101111) begin // Jump
				PCSource = 3;
				result = PC_EX + 4;
			end
			else if(IR_EX[6:0] == 7'b0010011) begin // Itype
				case(IR_EX[14:12])
					3'b000: begin
						result = oprnd1 + immI_EX;
					end
					3'b001: begin // SLL
						result = oprnd1 << immI_EX[4:0];
					end
					3'b010: begin // SLT
						result = $signed(oprnd1) < $signed(immI_EX);
					end
					3'b011: begin // SLTU
						result = oprnd1 < immI_EX;
					end
					3'b100: begin // XOR
						result = oprnd1 ^ immI_EX;
					end
					3'b101: begin // SRL, SRA
						if(IR_EX[31:25] == 7'b0000000) begin // SRL
							result = oprnd1 >> immI_EX[4:0];
						end
						if(IR_EX[31:25] == 7'b0100000) begin // SRA
							result = (oprnd1 >> immI_EX[4:0]) | (oprnd1[31] << 31);
						end
					end
					3'b110: begin // OR
						result = oprnd1 | immI_EX;
					end
					3'b111: begin // AND
						result = oprnd1 & immI_EX;
					end
				endcase
			end
			else begin // Branch
				result = oprnd1 + immB_EX;
				case(IR_EX[14:12])
					3'b000: begin // BEQ
						PCSource = (oprnd1 == oprnd2);
					end
					3'b010: begin // BNE
						PCSource = (oprnd1 != oprnd2);
					end
					3'b100: begin // BLT
						PCSource = ($signed(oprnd1) < $signed(oprnd2));
					end
					3'b101: begin // BGE
						PCSource = ($signed(oprnd1) >= $signed(oprnd2));
					end
					3'b110: begin // BLTU
						PCSource = (oprnd1 < oprnd2);
					end
					3'b111: begin // BGEU
						PCSource = (oprnd1 >= oprnd2);
					end
				endcase
				SAVOR = PCSource;
				PCBranch = ~PCSource;
			end
		end
	end

	always @(*) begin
		if(ALUOp) begin
			if(PCBranch) ALUOut = PC_EX+4; // branch WB value
			else ALUOut = result;
		end
	end

	// Calculate nextPC (at EX stage)
	always @(*) begin
		if(LocalJump) begin
			case(PCSource) // Decide the nextPC
				3'b001: begin //Branch (True case)
				nextPC = ALUOut[11:0];
				end
				3'b011: begin 
				nextPC = A_EX&12'hFFF; //JALR
				end
				3'b010: begin
				nextPC = (immJ_EX + PC_EX)&12'hFFF; // Jump
				end
				3'b000: begin
				nextPC = PC_EX+4; // Branch (False case)
				end
			endcase
		end
	end

	//4. Memory
	always @(*) begin
		if(~IorD) begin
			address = PC_MEM; // instruction memory
		end
		else begin
			address = ALUOut_MEM[11:0]; // Path__Store/WriteBack Stage, data memory
		end
	end

	assign D_MEM_CSN = ~RSTn;
	assign D_MEM_WEN = ~(IR_MEM[6:0] == 7'b0100011); // Wirte operation enable negative
	assign D_MEM_ADDR = address; //effectiveAddr;
	assign D_MEM_DOUT = B_MEM;
	assign D_MEM_BE = regBE;
	reg[2:0] temp;

	always @ (*) begin
		if(SigStage[3]) begin
			temp = IR_MEM[14:12];
			case(temp)
				2'b00: begin //*B
					regBE_MEM = 4'b0001;
				end
				2'b01: begin //*H
					regBE_MEM = 4'b0011;
				end
				2'b10: begin //*W
					regBE_MEM = 4'b1111;
				end
			endcase
		end
	end
	
	//Memory Input Sign Extending
	always @ (*) begin
		if(SigStage[3]) begin
			if(IR_MEM[6:0] == 7'b0000011) begin
				regMemOutput_MEM = D_MEM_DI;
				if(IR_MEM[14:12] == 3'b000) begin // lb
					if(regMemOutput_MEM[7] == 1'b1) begin
						regMemOutput_MEM = {24'b111111111111111111111111, D_MEM_DI[7:0]};
					end
					else begin
						regMemOutput_MEM = {24'b0, D_MEM_DI[7:0]};
					end
				end
				if(IR_MEM[14:12] == 3'b001) begin // lh
					regMemOutput_MEM = D_MEM_DI & 16'hFFFF;
					if(regMemOutput_MEM[15] == 1'b1) begin
						regMemOutput_MEM = {16'b1111111111111111, D_MEM_DI[15:0]};
					end
					else begin
						regMemOutput_MEM = {16'b0, D_MEM_DI[15:0]};
					end
				end
			end
		end
	end

	//5. Write Back Stage
	
	assign RF_WD = regWD;

	always @(*) begin
		if(SigStage[4]) begin
			if(IR_WB[6:0] == 7'b0000011) begin
				regWD = regMemOutput_WB;
			end
			else if(IR_WB[6:0] == 7'b1100011) begin
				regWD = SAVOR;
			end
			else if(RegWrite) begin
				regWD = ALUOut_WB;
			end
		end
	end

endmodule //
