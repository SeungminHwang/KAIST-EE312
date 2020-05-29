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
	output wire HALT,
	output reg [31:0] NUM_INST,
	output wire [31:0] OUTPUT_PORT
	);

	assign OUTPUT_PORT = RF_WD;

	initial begin
		NUM_INST <= 0;
	end

	// TODO: implement multi-cycle CPU

	// Control Signal Generate
	reg [31:0] I_MEM_DI_r;
	reg RegDest, RegWrite, MemRead, MemWrite, MemtoReg, ALUSrcA, IorD, IRWrite, PCWrite, PCWriteCond, PCWrite2, PCJalr, PCBranch, Gen_Imm, Complete,SAVOR;
	reg [1:0] ALUSrcB;
	reg [2:0] PCSource;

	// Some Needed Signal
	reg [11:0] currPC, PC;
	reg [11:0] nextPC, BranchPointer;

	wire [6:0] opcode;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [4:0] rd;
	wire [2:0] funct3;
	wire [6:0] funct7;
	reg [6:0] opcode_r;
	reg [4:0] rs1_r;
	reg [4:0] rs2_r;
	reg [4:0] rd_r;
	reg [2:0] funct3_r;
	reg [6:0] funct7_r;
	reg [11:0] address;

	assign opcode = opcode_r;
	assign rs1 = rs1_r;
	assign rs2 = rs2_r;
	assign rd = rd_r;
	assign funct3 = funct3_r;
	assign funct7 = funct7_r;

	wire [31:0] immI, immS, immB, immJ; // immediate
	reg [31:0] immI_r, immS_r, immB_r, immJ_r; // immediate register

	reg [18:0] offset19;
	reg [10:0] offset11;

	reg regHALT = 0;

	reg [31:0] result;
	reg [31:0] oprnd1;
	reg [31:0] oprnd2;

	reg [11:0] tmpPC; // PC produced by JMP/BRANCH
	reg [31:0] temp, A, B, ALUOut;
	wire bcond;

	reg [3:0] regBE;

	reg [31:0] regMemOutput;
	reg [31:0] regWD;


	assign I_MEM_CSN = ~RSTn;

	wire sigOpIMM, sigOP, sigJAL, sigJALR, sigBRANCH, sigLOAD, sigSTORE;
	reg sigOpIMM_r, sigOP_r, sigJAL_r, sigJALR_r, sigBRANCH_r, sigLOAD_r, sigSTORE_r;

	assign sigOpIMM =  sigOpIMM_r; // I type
	assign sigOP =  sigOP_r; //R type
	assign sigJAL =  sigJAL_r; // J type
	assign sigJALR =   sigJALR_r; // Itype
	assign sigBRANCH =  sigBRANCH_r; // B type
	assign sigLOAD =  sigLOAD_r; // I type
	assign sigSTORE =  sigSTORE_r; // S type

	//Control Flow
	reg[2:0] CtlFw, nextCtlFw;

	initial begin
		PC <= 0;
		currPC <= 0;
		CtlFw <= 0; // IF
	end

	always @(negedge CLK) begin
		if(RSTn & (Complete)) NUM_INST <= NUM_INST+1;
	end

	always @(posedge CLK) begin
		if (RSTn) begin
		/*
			if(Complete) begin
				CtlFw <= nextCtlFw;
				I_MEM_ADDR <= nextPC;
			end
			*/
			if(PCWrite|PCWriteCond) begin
				PC <= nextPC;
				CtlFw <= nextCtlFw;
				I_MEM_ADDR <= nextPC;
			end
			else begin
				I_MEM_ADDR <= PC;
				CtlFw <= nextCtlFw;
			end
		end
		else begin
			CtlFw <= 0;
			I_MEM_ADDR <= PC;
		end
	end

	assign immI = immI_r;
	assign immS = immS_r;
	assign immB = immB_r;
	assign immJ = immJ_r;

	//Control signals
	always @(*) begin
		case(CtlFw)
			3'b000: begin // IF
				Gen_Imm = 0;
				RegWrite = 0;
				PCBranch = 0;
				PCWrite2 = 0;
				PCJalr = 0;
				MemRead = 1;
				MemWrite = 0;
				MemtoReg = 0;
				ALUSrcA = 0;
				ALUSrcB = 1;
				IorD = 0;
				IRWrite = 0;
				PCWrite = 1;
				PCWriteCond = 0;
				PCSource = 0;
				nextCtlFw = CtlFw + 1; //goto ID
				Complete = 0;
			end
			3'b001: begin // ID
				Gen_Imm = 1;
				IRWrite = 1;
				ALUSrcA = 0;
				ALUSrcB = 3;
				nextCtlFw = CtlFw + 1; //goto Ex
				PCWrite = 0;
				PCWriteCond = 0;
				PCSource = 7;
				SAVOR=0;
			end
			3'b010: begin // EX
				Gen_Imm = 0;
				IRWrite = 0;
				if(sigOP)begin//Rtype
					ALUSrcA = 1;
					ALUSrcB = 0;
					nextCtlFw = CtlFw + 2;
					PCSource = 7;
				end
				else if(sigOpIMM)begin//Iype except Load, JALR
					ALUSrcA = 1;
					ALUSrcB = 2;
					nextCtlFw = CtlFw + 2;
					PCSource = 7;
				end
				else if(sigLOAD)begin//Load
					ALUSrcA = 1;
					ALUSrcB = 2;
					nextCtlFw = CtlFw + 1;
					PCSource = 7;
				end
				else if(sigJALR)begin//JALR
					ALUSrcA = 0;
					ALUSrcB = 2;
					nextCtlFw = CtlFw + 2;
					//PCJalr = 1;
					PCWrite = 1;
					PCSource = 3;
					RegWrite = 1;
				end
				else if (sigSTORE)begin//Store
					ALUSrcA = 1;
					ALUSrcB = 2;
					nextCtlFw = CtlFw + 1;
					PCSource = 7;
				end
				else if (sigJAL)begin//Jump
					PCSource = 2;
					ALUSrcA = 0;
					ALUSrcB = 1;
					PCWrite = 1;
					RegWrite = 1;
					nextCtlFw = CtlFw + 2;
				end
				else if(sigBRANCH) begin//Branch
					ALUSrcA = 0;
					ALUSrcB = 3;
					case(funct3)
						3'b000: begin // BEQ
							PCWriteCond = (A == B);
						end
						3'b010: begin // BNE
							PCWriteCond = (A != B);
						end
						3'b100: begin // BLT
							PCWriteCond = ($signed(A) < $signed(B));
						end
						3'b101: begin // BGE
							PCWriteCond = ($signed(A) >= $signed(B));
						end
						3'b110: begin // BLTU
							PCWriteCond = (A < B);
						end
						3'b111: begin // BGEU
							PCWriteCond = (A >= B);
						end
					endcase
					SAVOR = PCWriteCond;
					PCSource = 1;
					if(~PCWriteCond) begin 
						PCWrite = 1;
						PCBranch = 1;
					end
					nextCtlFw = 4; //goto Bracnch Comp.
				end
			end
			/*
			3'b111: begin // special stage, Branch Comp.
				nextCtlFw = 5;
				if(~PCWriteCond) begin 
					PCWrite = 1;
					PCBranch = 1;
				end
			end
			*/
			3'b011: begin // MEM
				PCWrite = 0;
				if(sigSTORE) begin //Store
					MemWrite = 1;
					IorD = 1;
					PCSource = 7;
					nextCtlFw = 0;
					Complete = 1;
				end
				else begin // Load
					MemRead = 1;
					IorD = 1;
					nextCtlFw = CtlFw + 1;
					PCSource = 7;
				end
			end
			3'b100: begin // WB
				PCWrite = 0;
				PCWriteCond = 0;
				if(sigOP|sigOpIMM) begin //Rtype or Itype except Load, Complete
					MemtoReg = 0;
					RegWrite = 1;
					PCWrite2 = 0;
					PCJalr = 0;
					PCSource = 7;
					nextCtlFw = 0;
					Complete = 1;
				end
				else if(sigJAL|sigJALR) begin
					MemtoReg = 0;
					RegWrite = 1;
					PCJalr = 0;
					PCWrite = 1;
					PCSource = 7;
					nextCtlFw = 0;
					Complete = 1;
				end
				else if (sigBRANCH) begin
					//PCWriteCond = 0;
					MemtoReg = 0;
					RegWrite = 0;
					Complete = 1;
					nextCtlFw = 0;
				end
				else begin //Load, Complete
					MemtoReg = 1;
					RegWrite = 1;
					PCSource = 7;
					nextCtlFw = 0;
					PCBranch = 0;
					Complete = 1;
				end
			end
			/*
			3'b101: begin //Complete Stage
				nextCtlFw = 0;
				PCWrite = 0;
				PCWriteCond = 0;
				Complete = 1;
				PCBranch = 0;
			end
			*/
		endcase
	end

	//Link wires to Register File
	assign RF_WE = ((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));
	assign RF_RA1 = rs1;
	assign RF_RA2 = rs2;
	assign RF_WA1 = rd;

	// terminate the Program __ Signal
	assign HALT = regHALT;
	always @ (*) begin
		if((I_MEM_DI == 32'h00008067) & (RF_RD1 == 32'h0000000c)) begin
			regHALT = 1;
		end
	end

	//IF

	always @(*) begin
		if(IRWrite) begin
			I_MEM_DI_r = I_MEM_DI;
		end
	end

	always @(*) begin
		if(IRWrite)begin
			opcode_r = I_MEM_DI_r[6:0];
			rs1_r = I_MEM_DI_r[19:15];
			rs2_r = I_MEM_DI_r[24:20];
			rd_r = I_MEM_DI_r[11:7];
			funct3_r = I_MEM_DI_r[14:12];
			funct7_r = I_MEM_DI_r[31:25];
		end
	end

	always @(*) begin
		if(IRWrite)begin
			sigOpIMM_r =  (opcode == 7'b0010011); // I type
			sigOP_r =  (opcode == 7'b0110011); //R type
			sigJAL_r =  (opcode == 7'b1101111); // J type
			sigJALR_r =  ( opcode == 7'b1100111 ); // Itype
			sigBRANCH_r =  (opcode == 7'b1100011); // B type
			sigLOAD_r =  (opcode == 7'b0000011); // I type
			sigSTORE_r =  (opcode == 7'b0100011); // S type
		end
	end

	// ID

	always @(*) begin
		if(Gen_Imm)begin
			offset19 = {I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31]};
			offset11 = {I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31],I_MEM_DI_r[31]};
			immI_r = {I_MEM_DI_r[31], offset19, I_MEM_DI_r[31], I_MEM_DI_r[30:25], I_MEM_DI_r[24:21], I_MEM_DI_r[20]};
			immS_r = {I_MEM_DI_r[31], offset19,I_MEM_DI_r[31], I_MEM_DI_r[30:25], I_MEM_DI_r[11:8], I_MEM_DI_r[7]};
			immB_r = {offset19, I_MEM_DI_r[31], I_MEM_DI_r[7], I_MEM_DI_r[30:25], I_MEM_DI_r[11:8], 1'b0};
			immJ_r = {offset11, I_MEM_DI_r[31], I_MEM_DI_r[19:12], I_MEM_DI_r[20], I_MEM_DI_r[30:25], I_MEM_DI_r[24:21], 1'b0};
		end
	end


	// Approach to Memory; Decide to instruction memory or data memory
	// Instruction Decode Stage
	always @(*) begin
		if(CtlFw == 1) begin
			A = RF_RD1;
			B = RF_RD2;
		end
	end

	// Determine operand
	always @(*) begin
		case(ALUSrcA)
			1'b0 : begin
				oprnd1 = currPC;		
			end
			1'b1 : begin
				oprnd1 = A;
			end
		endcase
		oprnd2 = B;
	end

	// ALU Module
	always @(*) begin
		if((CtlFw==0)|(CtlFw==1)|(CtlFw==2)) begin
			case(ALUSrcB)
				2'b00 : begin // Rtype
					case(funct3)
						3'b000: begin
							if(funct7 == 7'b0000000) begin // ADD
								result = oprnd1+oprnd2;
							end
							if(funct7 == 7'b0100000) begin // SUB
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
							if(funct7 == 7'b0000000) begin // SRL
								result = oprnd1 >> oprnd2[4:0];
							end
							if(funct7 == 7'b0100000) begin // SRA
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
				2'b01 : begin // Path__Instruction Fetch Stage
					result = oprnd1 + 4;
				end
				2'b10 : begin // Load, Store, Itype
					if(sigLOAD) begin // Load
						result = oprnd1 + immI;
					end
					else if (sigSTORE) begin // Store
						result = oprnd1 + immS;
					end
					else if(sigJALR) begin // JALR
						result = ((oprnd1 + immI)>>1)<<1;
						//result = PC+4;
					end
					else begin // Itype
						case(funct3)
							3'b000: begin
								result = oprnd1 + immI;
							end
							3'b001: begin // SLL
								result = oprnd1 << immI[4:0];
							end
							3'b010: begin // SLT
								result = $signed(oprnd1) < $signed(immI);
							end
							3'b011: begin // SLTU
								result = oprnd1 < immI;
								if(rs1 == 1'b0) begin
									result = (immI != 0);	// SLTU rd, x0, rs2 == 1 if rs2!=0, ...???..., What is 'oprnd2'?
								end
							end
							3'b100: begin // XOR
								result = oprnd1 ^ immI;
							end
							3'b101: begin // SRL, SRA
								if(funct7 == 7'b0000000) begin // SRL
									result = oprnd1 >> immI[4:0];
								end
								if(funct7 == 7'b0100000) begin // SRA
									result = (oprnd1 >> immI[4:0]) | (oprnd1[31] << 31);
								end
							end
							3'b110: begin // OR
								result = oprnd1 | immI;
							end
							3'b111: begin // AND
								result = oprnd1 & immI;
							end
						endcase
					end
				end
				2'b11 : begin // Branch
					result = oprnd1 + immB;
				end
			endcase
		end
	end

	always @(*) begin
		if(PCBranch) ALUOut = BranchPointer;
		else ALUOut = result;
	end

	always @(*) begin
		if(~IorD) begin
			address = PC; // instruction memory
		end
		else begin
			address = ALUOut[11:0]; // Path__Store/WriteBack Stage, data memory
		end
	end

	// Calculate nextPC
	always @(*) begin
		case(PCSource)
			3'b000: begin
				currPC = PC;
				nextPC = result[11:0];
				tmpPC = nextPC;
				BranchPointer = nextPC;
				end
			3'b001: begin
			nextPC = ALUOut[11:0];
			tmpPC = nextPC;
			end
			3'b011: begin 
			nextPC = A&12'hFFF; //JALR
			tmpPC = nextPC;
			end
			3'b010: begin
			nextPC = (immJ + currPC)&12'hFFF; // Jump
			tmpPC = nextPC;
			end
			3'b111: begin
			nextPC = tmpPC; //Hold on
			end
		endcase
	end

	// Store/ Writeback result Stage

	//Memory Control

	assign D_MEM_CSN = ~RSTn;
	assign D_MEM_WEN = ~sigSTORE; // Wirte operation enable negative
	assign D_MEM_ADDR = address; //effectiveAddr;
	assign D_MEM_DOUT = B;
	assign D_MEM_BE = regBE;

	always @ (*) begin
		case(funct3[1:0])
			2'b00: begin //*B
				regBE = 4'b0001;
			end
			2'b01: begin //*H
				regBE = 4'b0011;
			end
			2'b10: begin //*W
				regBE = 4'b1111;
			end
		endcase
	end
	
	//mem input sign extending

	always @ (*) begin
		if(sigLOAD) begin
			regMemOutput = D_MEM_DI;
			if(funct3 == 3'b000) begin // lb
				if(regMemOutput[7] == 1'b1) begin
					regMemOutput = {24'b111111111111111111111111, D_MEM_DI[7:0]};
				end
				else begin
					regMemOutput = {24'b0, D_MEM_DI[7:0]};
				end
			end
			if(funct3 == 3'b001) begin // lh
				regMemOutput = D_MEM_DI & 16'hFFFF;
				if(regMemOutput[15] == 1'b1) begin
					regMemOutput = {16'b1111111111111111, D_MEM_DI[15:0]};
				end
				else begin
					regMemOutput = {16'b0, D_MEM_DI[15:0]};
				end
			end
		end
	end


	//Write Back Stage
	
	assign RF_WD = regWD;

	always @(*) begin
		if(MemtoReg) begin
			regWD = regMemOutput;
		end
		else if(sigSTORE) begin
			regWD = ALUOut;
		end
		else if(sigBRANCH) begin
			regWD = SAVOR;
		end
		/*
		else if(sigJALR) begin
			regWD = BranchPointer;
		end
		*/
		else if(RegWrite) begin
			regWD = ALUOut;
		end
	end

endmodule //
