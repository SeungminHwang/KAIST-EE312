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

	// TODO: implement multi-cycle CPU

	//custom wires and registers

	reg [31:0] PC;
	reg [31:0] nextPC;
	reg [31:0] IR; // insturction register
	
	//Stage control
	reg [2:0] stage;
	wire [2:0] nextStage;
	
	wire PVSWriteEn;


	wire [6:0] opcode;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [4:0] rd;
	wire [2:0] funct3;
	wire [6:0] funct7;

	wire [31:0] immI; // immediate for I
	wire [31:0] immS; // immediate for S
	wire [31:0] immB; // immediate for B
	wire [31:0] immU; // immediate for U
	wire [31:0] immJ; // immediate for J

	
	wire sigOpIMM;
	wire sigLUI;
	wire sigAUIPC;
	wire sigOP;
	wire sigJAL;
	wire sigJALR;
	wire sigBRANCH;
	wire sigLOAD;
	wire sigSTORE;

	wire sigALUSrc;
	wire sigMemToReg;

	wire [31:0] imm;
	reg [31:0] immField;

	reg regHALT = 0;

	wire [31:0] result;
	wire [31:0] oprnd1;
	wire [31:0] oprnd2;

	reg [11:0] jmpPC; // PC produced by JMP/BRANCH
	reg [31:0] temp;
	wire bcond;

	reg [3:0] regBE;

	reg [31:0] regMemOutput;
	reg [31:0] regWD;



	initial begin
		PC <= 0;
		stage <= 0;
	end

	initial begin
		NUM_INST <= 0;
	end

	always @ (negedge CLK) begin
	  	if(RSTn && PVSWriteEn) begin
			NUM_INST <= NUM_INST + 1;	
		end
	end

	always @ (posedge CLK) begin
		if (RSTn) begin
			if(PVSWriteEn) begin // if all stage are done
				PC <= nextPC;
				I_MEM_ADDR <= nextPC;
			end
			else begin
			  	I_MEM_ADDR <= PC;
			end
			stage <= nextStage; // just one stage is done.
		end
		else begin
			I_MEM_ADDR <= PC;
		end
	end


	//part a.
	assign I_MEM_CSN = ~RSTn;
	assign D_MEM_CSN = ~RSTn;
	assign OUTPUT_PORT = RF_WD;

	//micro control unit
	STAGECTRL STAGECTRL(.currentStage(stage), .opcode(I_MEM_ADDR[6:0]), .nextStage(nextStage), .PVSWriteEn(PVSWriteEn));


	//IF
	always @ (*) begin
		if(stage == 3'b000) begin //only for IF
			$display("PC: ",I_MEM_ADDR);
			//I_MEM_ADDR = PC;
			IR = I_MEM_DI;
		end
	end

	//ID
	wire isID = (stage == 3'b001);
	INST_DECODE INST_DECODE(.INST(I_MEM_DI), .activate(isID), .opcode(opcode), .rs1(rs1), .rs2(rs2), .rd(rd), .funct3(funct3), .funct7(funct7), .immI(immI), .immS(immS), .immB(immB), .immU(immU), .immJ(immJ), .sigOpIMM(sigOpIMM), .sigOP(sigOP), .sigJAL(sigJAL), .sigJALR(sigJALR), .sigBRANCH(sigBRANCH), .sigLOAD(sigLOAD), .sigSTORE(sigSTORE), .sigALUSrc(sigALUSrc), .sigMemToReg(sigMemToReg), .RF_WE(RF_WE), .RF_RA1(RF_RA1), .RF_RA2(RF_RA2), .RF_WA1(RF_WA1), .RF_RD1(RF_RD1), .RF_RD2(RF_RD2), .oprnd2(oprnd2), .HALT(HALT));


	//Ex
	//ALU for OP and OPIMM
	//fix activate, oprnd2
	wire isALU = sigOP| sigOpIMM;
	ALU ALU(.activate(isALU), .op(funct3), .subop(funct7), .oprnd1(RF_RD1), .oprnd2(oprnd2), .res(result));
	

	//deal with branch and jump
	/*always @ (*) begin

	end*/

	//MEM
	//reg isMEM = (stage == 3'b011);
	//if(isMEM) begin
		assign D_MEM_WEN = ~sigSTORE;
		assign D_MEM_ADDR = result[11:0];
		assign D_MEM_DOUT = RF_RD2;
		assign D_MEM_BE = regBE;
	
	always @ (*) begin
		if(stage == 3'b011) begin //only for MEM
			case(funct3[1:0])
				2'b00: regBE = 4'b0001; //*B
				2'b01: regBE = 4'b0011; //*H
				2'b10: regBE = 4'b1111; //*W
			endcase

			if(sigLOAD) begin
				regMemOutput = D_MEM_DI;
				if(funct3 == 3'b000) begin // lb
					//regMemOutput = regMemOutput[7:0];// & 8'hFF;
					if(regMemOutput[7] == 1'b1) begin
						regMemOutput = {24'b111111111111111111111111, D_MEM_DI[7:0]};
					end
					else begin
						regMemOutput = D_MEM_DI&8'hFF;//{24'b0, D_MEM_DI[7:0]};
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
				if(funct3 == 3'b100) begin // lbu
					regMemOutput = D_MEM_DI& 8'hFF;
				end
				if(funct3 == 3'b101) begin //lhu
					regMemOutput = D_MEM_DI & 16'hFFFF;
				end
			end
		end
	end

	//WB

	assign RF_WD = regWD;
	always @ (*) begin
	  	if(stage == 3'b100) begin //only for WB
			if(sigMemToReg) begin
			  	regWD = regMemOutput;
			end
			else if(sigJAL) begin
			  	regWD = PC + 4;
			end
			else begin
			  	regWD = result;
			end
		end
	end













endmodule //
