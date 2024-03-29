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
	reg [31:0] reg_oprnd1;
	reg [31:0] reg_oprnd2;
	//assign oprnd1 = reg_oprnd1;
	//assign oprnd2 = reg_oprnd2;

	reg [11:0] jmpPC; // PC produced by JMP/BRANCH
	reg [31:0] temp;
	wire bcond;

	reg [3:0] regBE;

	reg [31:0] regMemOutput;
	reg [31:0] regWD;

	reg [31:0] reg_result;



	initial begin
		PC <= 0;
		stage <= 0;//3'b101;
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
		$display("RSTN", RSTn);
		if (RSTn) begin
			//$display("nextInstr, PC: ", stage, PC);
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
			stage <= 0;
			//$display("IMEMADDR, stage: ",I_MEM_ADDR, stage, IR);
		end
	end


	//part a.
	assign I_MEM_CSN = ~RSTn;
	assign D_MEM_CSN = ~RSTn;
	assign OUTPUT_PORT = RF_WD;

	//micro control unit
	//wire [6:0] temp1 = I_MEM_ADDR[6:0];
	STAGECTRL STAGECTRL(.currentStage(stage), .opcode(opcode), .nextStage(nextStage), .PVSWriteEn(PVSWriteEn), .rstn(RSTn));


	//IF
	always @ (*) begin
		if(stage == 3'b000) begin //only for IF
			//$display("RSTn: ",RSTn);
			//I_MEM_ADDR = PC;
			IR = I_MEM_DI;
		end
	end

	//ID
	wire isID = 1;//(stage == 3'b001);
	INST_DECODE INST_DECODE(.INST(I_MEM_DI), .activate(isID), .opcode(opcode), .rs1(rs1), .rs2(rs2), .rd(rd), .funct3(funct3), .funct7(funct7), .immI(immI), .immS(immS), .immB(immB), .immU(immU), .immJ(immJ), .sigOpIMM(sigOpIMM), .sigOP(sigOP), .sigJAL(sigJAL), .sigJALR(sigJALR), .sigBRANCH(sigBRANCH), .sigLOAD(sigLOAD), .sigSTORE(sigSTORE), .sigALUSrc(sigALUSrc), .sigMemToReg(sigMemToReg), .RF_WE(RF_WE), .RF_RA1(RF_RA1), .RF_RA2(RF_RA2), .RF_WA1(RF_WA1), .RF_RD1(RF_RD1), .RF_RD2(RF_RD2), .oprnd2(oprnd2), .oprnd1(oprnd1), .HALT(HALT), .writeEn(PVSWriteEn));

	//control signals
	/*
	assign sigOpIMM =  (opcode == 7'b0010011); // I type
	assign sigLUI =  (opcode == 7'b0110111);
	assign sigAUIPC =  ( opcode == 7'b0010111 );
	assign sigOP =  (opcode == 7'b0110011); //R type
	assign sigJAL =  (opcode == 7'b1101111); // J type
	assign sigJALR =  ( opcode == 7'b1100111 ); // Itype
	assign sigBRANCH =  (opcode == 7'b1100011); // B type
	assign sigLOAD =  (opcode == 7'b0000011); // I type
	assign sigSTORE =  (opcode == 7'b0100011); // S type

	assign sigALUSrc =  (sigOP) | (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate
	assign sigMemToReg =  sigLOAD;
	
	assign RF_WE = ((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));
	assign RF_RA1 = rs1;
	assign RF_RA2 = rs2;
	assign RF_WA1 = rd;
	*/
	




	//Ex
	//ALU for OP and OPIMM
	//fix activate, oprnd2
	wire isALU = (stage == 3'b010);// &(sigOP| sigOpIMM);
	/*
	always @ (*) begin
		if(sigOpIMM) reg_oprnd2 = immI;
		else reg_oprnd2 = oprnd2;
	end*/
	wire [31:0] aluop2;
	assign aluop2 = oprnd2;
	always @ (*) begin
		$display("stg %x-%x, PC: %x, op1: %x, op2: %x, result: %x", NUM_INST + 1,stage,PC, oprnd1, aluop2, result);
		$display("test: %x", IR);
		if(stage == 3'b001) begin
			if(sigOpIMM) reg_oprnd2 = immI;
			if(sigOP) reg_oprnd2 = oprnd2;
		end
	end
	ALU ALU(.activate(isALU), .op(funct3), .subop(funct7), .oprnd1(oprnd1), .oprnd2(aluop2), .res(result));
	

	//deal with branch and jump
	assign bcond = result;
	always @ (*) begin // branch
		if(stage == 3'b010) begin // only for EX stage
			if(sigBRANCH) begin // branch
				case(funct3)
					3'b000: reg_result = (oprnd1 == oprnd2);//BEQ
					3'b010: reg_result = (oprnd1 != oprnd2);//BNE
					3'b100: reg_result = ($signed(oprnd1) < $signed(oprnd2));//BLT
					3'b101: reg_result = ($signed(oprnd1) >= $signed(oprnd2));//BGE
					3'b110: reg_result = (oprnd1 < oprnd2);
					3'b111: reg_result = (oprnd1 >= oprnd2);
				endcase
			end

			if(sigLOAD | sigSTORE) begin
			  	reg_result = oprnd1 + imm;
				nextPC = PC + 4;
			end
			if(sigJAL) begin
			  	jmpPC = (imm + PC)&12'hFFF;
				reg_result = PC + 4;
				//$display("you got it!:", reg_result);
			end
			if(sigJALR) begin
			  	jmpPC = oprnd1 & 12'hFFF;
				reg_result = ((oprnd1 + imm) >> 1) << 1;
			end

			if(sigBRANCH & bcond) begin
			  	temp = imm + PC;
				nextPC = temp[11:0];
			end



		end
	end

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
	  	if((stage == 4)) begin //only for WB
		  $display("reg_result", sigJAL, sigMemToReg, PVSWriteEn);
		  	nextPC = PC + 4;
			  $display("isItOkay?", sigJAL);
			if(sigMemToReg) begin
			  	regWD = regMemOutput;
			end
			else if(sigJAL) begin
			  	regWD = reg_result;
				$display("good!", reg_result);
			end
			else begin
			  	regWD = result;
			end
		end
		//$display(regWD);
		//$display("stage, INST, nPC: ", stage, I_MEM_DI, nextPC, RSTn);
	end

	always @ (*) begin
		if(sigJAL | sigJALR | (sigBRANCH & bcond)) begin
			nextPC = jmpPC;
		end
		else begin
			$display("no!", sigJAL);
			nextPC = PC + 4;
		end
	end












endmodule //