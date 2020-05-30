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

	// Only allow for NUM_INST
	always @ (negedge CLK) begin
		if (RSTn) NUM_INST <= NUM_INST + 1;
	end

	// TODO: implement


	// MEM module synchronize
	assign I_MEM_CSN = ~RSTn;
	assign D_MEM_CSN = ~RSTn;
	assign OUTPUT_PORT = RF_WD;



	
	always @ (posedge CLK) begin // update all of the signals
		if (RSTn) begin
			PC <= nextPC;
			I_MEM_DI <= nextPC;


			// MEM => WB


			// EXE -> MEM

			// ID -> EXE


			// IF -> ID
			

			

			


			

		end	
	end
	

	reg [11:0] PC; // Program Counter
	reg [11:0] nextPC;


	// Stage 1. IF



	//// results of instruction fetch
	reg [31:0] IF_IR;
	reg [11:0] IF_nextPC;



	// Stage 2. ID/RF
	// Input: IF_IR, IF_nextPC;

	//// working wiht Register module
	//// (레지스터 신호 꽂아주는 역할을 합니다)
	assign RF_RA1 = IF_IR[19:15]; // rs1
	assign RF_RA2 = IF_IR[24:20]; // rs2


	//// Instruction decoding part
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

	reg HALT_r;
	assign HALT = HALT_r


	reg [31:0] immI_r, immS_r, immB_r, immJ_r, immU_r;
	wire [31:0] immI, immS, immB, immJ, immU;
	assign immI = immI_r;
	assign immS = immS_r;
	assign immB = immB_r;
	assign immJ = immJ_r;
	assign immU = immU_r;

	reg [31:0] op1_r, op2_r;
	wire [31:0] op1, op2;
	assign op1 = op1_r;
	assign op2 = op2_r;
	

	//// Signal generating part(temporary signals)
	wire sigOpIMM, sigOP, sigJAL, sigJALR, sigBRANCH, sigLOAD, sigSTORE
	sigOpIMM = (opcode == 7'b0010011); // I type
	sigOP = (opcode == 7'b0110011); //R type
	sigJAL = (opcode == 7'b1101111); // J type
	sigJALR = ( opcode == 7'b1100111 ); // Itype
	sigBRANCH = (opcode == 7'b1100011); // B type
	sigLOAD = (opcode == 7'b0000011); // I type
	sigSTORE = (opcode == 7'b0100011); // S type


	wire sigALUSrc, sigMemToReg;
	sigALUSrc =  (sigOP) | (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate
	sigMemToReg =  sigLOAD;
	RF_WE = ((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));//&writeEn;
	//RF_WE는 생각해보기

	
	always @ (*) begin
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

	//// results of instruction decode
	////// About WB
	reg [4:0] ID_WBDest; //rd  = IF_IR[11:7]; // rd
	reg ID_RF_WE; //((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));//&writeEn;
	reg ID_sigMemToReg; // sigLoad

	////// About MEM
	reg ID_sigMemWrite;
	reg ID_sigMemRead;

	////// About EXE
	reg [31:0] ID_OP1;
	reg [31:0] ID_OP2;
	reg [2:0] ID_funct3;// = IF_IR[14:12];
	reg [6:0] ID_funct7;// = IF_IR[31:25];

	reg [31:0] ID_immI;
	reg [31:0] ID_immS;
	reg [31:0] ID_immB;
	reg [31:0] ID_immJ;
	reg [31:0] ID_immU;

	reg ID_sigALUSrc; // (sigOP) | (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate


	// Stage 3. EXE
	wire [31:0] result;
	wire [31:0] aluOp1;
	wire [31:0] aluOp2;
	assign aluOp1 = ID_OP1;
	assign aluOp2 = ID_OP2;

	////for OPIMM and OP
	ALU ALU(.activate(1), .op(funct3), .subop(funct7), .op1(aluOp1), .op2(aluOp2), .res(result));


	// pleas implement jump and branch!!



	//// results of execution
	////// About WB
	reg [4:0] EXE_WBDest;
	reg EXE_RF_WE;
	reg EXE_sigMemToReg;

	////// About MEM
	reg EXE_sigMemRead; // ID거 그대로
	reg EXE_sigMemWrite; // ID거 그대로
	reg [31:0] EXE_MemAddr; // memory address
	reg [31:0] EXE_WriteData; // memory write data
	reg [3:0] EXE_funct3; // *B *L *W



	// Stage 4. MEM

	//// assign values to the D MEM
	assign D_MEM_WEN = ~EXE_sigMemWrite; // sigstore
	assign D_MEM_ADDR = EXE_MemAddr;
	assign D_MEM_DOUT = EXE_WriteData;
	reg [3:0] BE_r;
	assign D_MEM_ADDR = BE_r;


	wire [31:0] memOutput;
	reg [31:0] memOutput_r;
	assign memOutput = memOutput_r;

	always @ (*) begin
		case(EXE_funct3[1:0])
			2'b00: BE_r = 4'b0001; //*B
			2'b01: BE_r = 4'b0011; //*H
			2'b10: BE_r = 4'b1111; //*W
		endcase
		if(EXE_sigMemRead) begin
			memOutput_r = D_MEM_DI;
			if(EXE_funct3 == 3'b000) begin // lb
				if(memOutput_r[7] == 1'b1) begin
					memOutput_r = {24'b111111111111111111111111, D_MEM_DI[7:0]};
				end
				else begin
					memOutput_r = D_MEM_DI&8'hFF;
				end
			end
			if(EXE_funct3 == 3'b001) begin // lh
				memOutput_r = D_MEM_DI & 16'hFFFF;
				if(memOutput_r[15] == 1'b1) begin
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


	//// results of Memory access
	////// About WB
	reg [4:0] MEM_WB_Dest;
	reg MEM_RF_WE;
	reg MEM_sigMemToReg;
	
	reg [31:0] MEM_memOutput; // output from memory;
	reg [31:0] MEM_ALU_result; // EXE_Write_Data;



	// Stage 5. WB
	reg [31:0] WD_r;
	assign RF_WD = WD_r;
	assign RF_WE = MEM_RF_WE; // write enable


	always @ (*) begin
		if(MEM_sigMemToReg) begin
			WD_r = MEM_memOutput;
		end
		else begin
			WD_r = MEM_ALU_result;
		end
	end

	





endmodule //
