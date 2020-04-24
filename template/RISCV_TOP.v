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
	output wire [4:0] RF_RA1, // Read reg. 1
	output wire [4:0] RF_RA2, // Read reg. 2
	output wire [4:0] RF_WA1, // Write Addr.
	input wire [31:0] RF_RD1, //Read Data 1
	input wire [31:0] RF_RD2, //Read Data 2
	output wire [31:0] RF_WD, // Write Data
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
	reg [11:0] PC;
	reg [11:0] nextPC;

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

	wire [18:0] offset19 = {I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31]};
	wire [10:0] offset11 = {I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31],I_MEM_DI[31]};
 	
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

	reg [31:0] result;
	reg [31:0] oprnd1;
	reg [31:0] oprnd2;

	reg [11:0] jmpPC; // PC produced by JMP/BRANCH
	reg [31:0] temp;
	wire bcond;

	reg [3:0] regBE;

	reg [31:0] regMemOutput;
	reg [31:0] regWD;


	assign I_MEM_CSN = ~RSTn;

	
	initial begin
		PC = 0;
	end
	always @ (*) begin
		if(sigJAL | sigJALR | (sigBRANCH & bcond)) begin
			nextPC = jmpPC;
		end
		else begin
			nextPC = PC + 4;
		end
	end

	always @(posedge CLK) begin
		if (RSTn) begin
			PC <= nextPC;
			I_MEM_ADDR <= nextPC;
		end
		else begin
			I_MEM_ADDR <= PC;
		end
	end

	//wires from IM to Instruction Decoder
	

	assign opcode = I_MEM_DI[6:0];
	assign rs1 = I_MEM_DI[19:15];
	assign rs2 = I_MEM_DI[24:20];
	assign rd = I_MEM_DI[11:7];
	assign funct3 = I_MEM_DI[14:12];
	assign funct7 = I_MEM_DI[31:25];

	assign immI = {I_MEM_DI[31], offset19, I_MEM_DI[31], I_MEM_DI[30:25], I_MEM_DI[24:21], I_MEM_DI[20]};
	assign immS = {I_MEM_DI[31], offset19,I_MEM_DI[31], I_MEM_DI[30:25], I_MEM_DI[11:8], I_MEM_DI[7]};
	assign immB = {offset19, I_MEM_DI[31], I_MEM_DI[7], I_MEM_DI[30:25], I_MEM_DI[11:8]};
	assign immU = {I_MEM_DI[31], I_MEM_DI[30:20], I_MEM_DI[19:12], 12'b000000000000};
	assign immJ = {I_MEM_DI[31], I_MEM_DI[19:12], I_MEM_DI[20], I_MEM_DI[30:25], I_MEM_DI[24:21]};


	//Control signals
	

	assign sigOpIMM =  (opcode == 7'b0010011); // I type
	assign sigLUI =  (opcode == 7'b0110111);
	assign sigAUIPC =  ( opcode == 7'b0010111 );
	assign sigOP =  (opcode == 7'b0110011); //R type
	assign sigJAL =  (opcode == 7'b1101111); // J type
	assign sigJALR =  ( opcode == 7'b1100111 ); // Itype
	assign sigBRANCH =  (opcode == 7'b1100011); // B type
	assign sigLOAD =  (opcode == 7'b0000011); // I type
	assign sigSTORE =  (opcode == 7'b0100011); // S type

	assign sigALUSrc =  (sigOP) & (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate
	assign sigMemToReg =  sigLOAD;
	



	// make immediate filed
	assign imm = immField;
	always @ (*) begin
		//$display("INST: ", I_MEM_DI);
		//$display("WD: ", RF_WD);
		//$display("op1: ", oprnd1);
		//$display("op2: ", oprnd2);
		//$display("res: ", imm);
		//$display("funct3: ", funct7);
		//$display("rd: ", rd);
		//$display("res: ", result);
		//$display("PC: ", RSTn);
		//$display("regMemoutput", regWD);
		
		
		if(sigOpIMM | sigJALR | sigLOAD) begin // isItype
			immField = immI;
		end
		if(sigBRANCH) begin // isBtype
			immField = immB;
		end
		if(sigJAL) begin // isJtype
			immField = immJ;
		end
		if(sigSTORE) begin // isStype
			immField = immS;
		end
		if(sigLUI | sigAUIPC) begin // isUtype
			immField = immU;
		end
	end
	


	//Link wires to Register File
	assign RF_WE = ((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));
	assign RF_RA1 = rs1;
	assign RF_RA2 = rs2;
	assign RF_WA1 = rd;
	
	assign HALT = regHALT;


	// ALU
	//// ALU control
	always @ (*) begin
		oprnd1 = RF_RD1;
		oprnd2 = RF_RD2;
		if(~sigALUSrc) begin
			oprnd2 = imm;
		end

		//HALT
		if((I_MEM_DI == 32'h00008067) & (RF_RD1 == 32'h0000000c)) begin
			regHALT = 1;		  
		end

		if(sigOP) begin// | sigOpIMM) begin //R-type ALU
			case(funct3)
				3'b000: begin
					if(funct7 == 7'b0000000) begin // ADD
						result = RF_RD1 + RF_RD2;
					end
					if(funct7 == 7'b0100000) begin // SUB
						result = RF_RD1 - RF_RD2;
					end
				end
				3'b001: begin // SLL
					result = RF_RD1 << RF_RD2[4:0];
				end
				3'b010: begin // SLT
					result = $signed(RF_RD1) < $signed(RF_RD2);
				end
				3'b011: begin // SLTU
					result = RF_RD1 < RF_RD2;
				end
				3'b100: begin // XOR
					result = RF_RD1 ^ RF_RD2;
				end
				3'b101: begin // SRL, SRA
					if(funct7 == 7'b0000000) begin // SRL
						result = RF_RD1 >> RF_RD2[4:0];
					end
					if(funct7 == 7'b0100000) begin // SRA
						result = (RF_RD1 >> RF_RD2[4:0]) | (RF_RD1[31] << 31);
					end
				end
				3'b110: begin // OR
					result = RF_RD1 | RF_RD2;
				end
				3'b111: begin // AND
					result = RF_RD1 & RF_RD2;
				end
			endcase
		end

		if(sigBRANCH) begin // B-type ALU
			case(funct3)
				3'b000: begin // BEQ
					result = (oprnd1 == oprnd2);
				end
				3'b010: begin // BNE
					result = (oprnd1 != oprnd2);
				end
				3'b100: begin // BLT
					result = ($signed(oprnd1) < $signed(oprnd2));
				end
				3'b101: begin // BGE
					result = ($signed(oprnd1) >= $signed(oprnd2));
				end
				3'b110: begin // BLTU
					result = (oprnd1 < oprnd2);
				end
				3'b111: begin // BGEU
					result = (oprnd1 >= oprnd2);
				end
			endcase
		end
		
		if(sigOpIMM) begin // OP IMM
			case(funct3)
				3'b000: begin
					result = oprnd1 + imm;
				end
				3'b001: begin // SLL
					result = oprnd1 << imm[4:0];
				end
				3'b010: begin // SLT
					result = $signed(oprnd1) < $signed(imm);
				end
				3'b011: begin // SLTU
					result = oprnd1 < imm;
				end
				3'b100: begin // XOR
					result = oprnd1 ^ imm;
				end
				3'b101: begin // SRL, SRA
					if(funct7 == 7'b0000000) begin // SRL
						result = oprnd1 >> imm[4:0];
					end
					if(funct7 == 7'b0100000) begin // SRA
						result = (oprnd1 >> imm[4:0]) | (oprnd1[31] << 31);
					end
				end
				3'b110: begin // OR
					result = oprnd1 | imm;
				end
				3'b111: begin // AND
					result = oprnd1 & imm;
				end
			endcase
		end

		if(sigLOAD | sigSTORE) begin // calculating effective addr
			result = oprnd1 + imm; // op2 = imm
		end

		if(sigLUI) begin
			result = oprnd2; //imm
		end
		if(sigAUIPC) begin
			result = PC + oprnd2; //imm
		end
	end

	//jump!
	
	assign bcond = ~result;
	always @ (*) begin
		if(sigJAL) begin
			temp = ((imm<<1) + PC);
			jmpPC = temp[11:0];
			//result = 0;
		end
		if(sigJALR) begin
			temp = oprnd1 + imm;
			temp = temp & (-2);
			temp = (temp<<1) + PC;
			jmpPC = temp[11:0];
		end

		if(sigBRANCH & bcond) begin
			temp = ((imm<<1) + PC);
			jmpPC = temp[11:0];
		end
	end


	//mem control
	//wire [11:0] effectiveAddr = assign result & 12'hFFF;
	assign D_MEM_CSN = ~RSTn;
	assign D_MEM_WEN = ~sigSTORE; // Wirte operation enable negative
	assign D_MEM_ADDR = result[11:0];//effectiveAddr;
	assign D_MEM_DOUT = RF_RD2;

	
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
		case(funct3)
			3'b100: begin //LBU 8
				regMemOutput = D_MEM_DI;
			end
			3'b101: begin //*LHU 16
				regMemOutput = D_MEM_DI;
			end
			3'b000: begin //*B 8
				if(D_MEM_DI[7] == 1) begin
					regMemOutput = {24'b111111111111111111111111, D_MEM_DI};
				end
				else begin
				  regMemOutput = D_MEM_DI;
				end
			end
			3'b001: begin //*H 16
				if(D_MEM_DI[15] == 1) begin
					regMemOutput = {16'b1111111111111111, D_MEM_DI};
				end
				else begin
				  regMemOutput = D_MEM_DI;
				end
			end
			3'b010: begin //*W 32
				regMemOutput = D_MEM_DI;
			end
		endcase
	end


	//Write Back Stage
	
	assign RF_WD = regWD;
	always @ (*) begin
		if(sigMemToReg) begin
			regWD = regMemOutput;
		end
		else begin
			regWD = result;
		end
	end



	

endmodule //
