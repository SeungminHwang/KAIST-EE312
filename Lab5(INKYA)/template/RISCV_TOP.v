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
	reg[31:0] A_ID, A_EX, A_MEM, A_temp, B_ID, B_EX, B_MEM, B_temp;
	reg sigOP_ID, sigOP_EX, nextsigOP_EX;
	reg sigOPImm_ID, sigOPImm_EX, nextsigOPImm_EX;
	reg sigLoad_ID, sigLoad_EX, sigLoad_MEM, sigLoad_WB, nextsigLoad_EX, nextsigLoad_MEM,nextsigLoad_WB;
	reg sigStore_ID, sigStore_EX, sigStore_MEM, sigStore_WB, nextsigStore_EX, nextsigStore_MEM, nextsigStore_WB;
	reg sigBranch_ID, sigBranch_EX, sigBranch_MEM, sigBranch_WB, nextsigBranch_EX, nextsigBranch_MEM, nextsigBranch_WB;
	reg sigJump_ID, sigJump_EX, nextsigJump_EX;
	reg sigJALR_ID, sigJALR_EX, nextsigJALR_EX;
	reg[2:0] func3_ID, func3_EX, func3_MEM, nextfunc3_EX, nextfunc3_MEM;
	reg[6:0] func7_ID, func7_EX, nextfunc7_EX;

    // BTB
    reg[11:0] BranchPointer, partition2;
    reg[25:0] BTB, nextBTB; // BTB[11:0] = nextPC, BTB[23:12] = PC_Branch, BTB[25:24] = idx
    reg Active_BTB, Change_BTB, Finish_BTB;
    reg InitForBranch, taken, success, FirstLoop, check2, nextcheck2;
	reg [1:0] partition1;

	// Forwarding Unit
	reg Harzard_Level, nextHarzard_Level, Gen_Danger;
	reg[2:0] ForwardA, ForwardA_ID, HarzardCounter, nextHarzardCounter, ForwardB, ForwardB_ID;

	// Harzard Control
	reg[4:0] RD_ID, RD_EX, RD_MEM, RD_WB, nextRD_EX, nextRD_MEM, nextRD_WB;
	reg[4:0] RS1, RS2;
	reg [2:0] Counter, nextCounter;
	reg tmp, free, nextfree, change;
	reg init, nextinit;
	reg danger, tmp2, treeout, treeout2;
	reg check, nextcheck;

	// Signal
	reg[4:0] SigStage = 5'b00000;
	reg[4:0] nextSigStage;
	reg IRWrite, PCWrite, IDWrite, Gen_Imm, ALUOp, IorD, RegWrite, LocalJump, regHALT, PCBranch;
	reg [2:0] PCSource;

	// Register
	reg[4:0] rd, rs1, rs2;
	reg[31:0] immI_ID, immI_EX, immJ_ID, immJ_EX, immS_ID, immS_EX, immB_ID, immB_EX, ALUOut, ALUOut_MEM, ALUOut_WB, ALUOut_temp, result, regWD, regMemOutput_MEM, regMemOutput_WB, oprnd1, oprnd2;
	reg[3:0] regBE, regBE_MEM;
	reg[11:0] address;
	reg SAVOR;

	initial begin
		Counter <= 1;
		nextCounter <= 1;
		PC <= 0;
		nextPC <= 0;
		init <= 0;
		nextinit <= 0;
		free <= 0;
		check <= 0;
		change <= 0;
        BTB <= 0;
        nextBTB <= 0;
		success <= 0;
		Harzard_Level <= 0;
		nextHarzard_Level <= 0;
		HarzardCounter <= 0;
		nextHarzardCounter <= 0;
		ForwardA <= 0;
		ForwardA_ID <= 0;
		ForwardB <= 0;
		ForwardB_ID <= 0;
	end

	assign I_MEM_CSN = ~RSTn;

	// Update
	always @(posedge CLK) begin
		if (RSTn) begin
			if(PCWrite) begin
				PC <= nextPC;
				I_MEM_ADDR <= nextPC;
			end
			else begin
				I_MEM_ADDR <= PC;
			end
			init <= nextinit;
			PC_ID <= nextPC_ID;
			PC_EX <= nextPC_EX;
			PC_MEM <= nextPC_MEM;
			PC_WB <= nextPC_WB;
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
			Counter <= nextCounter;
			ALUOut_MEM <= ALUOut;
			ALUOut_WB <= ALUOut_temp;
			A_EX <= A_ID;
			B_EX <= B_ID;
			A_MEM <= A_temp;
			B_MEM <= B_temp;
			free <= nextfree;
			check <= nextcheck;
            BTB <= nextBTB;
			check2 <= nextcheck2;
			Harzard_Level <= nextHarzard_Level;
			HarzardCounter <= nextHarzardCounter;
			ForwardA_ID <= ForwardA;
			ForwardB_ID <= ForwardB;

			sigOP_EX <= nextsigOP_EX;
			sigOPImm_EX <= nextsigOPImm_EX;
			sigLoad_EX <= nextsigLoad_EX;
			sigLoad_MEM <= nextsigLoad_MEM;
			sigLoad_WB <= nextsigLoad_WB;
			sigStore_EX <= nextsigStore_EX;
			sigStore_MEM <= nextsigStore_MEM;
			sigStore_WB <= nextsigStore_WB;
			sigBranch_EX <= nextsigBranch_EX;
			sigBranch_MEM <= nextsigBranch_MEM;
			sigBranch_WB <= nextsigBranch_WB;
			sigJump_EX <= nextsigJump_EX;
			sigJALR_EX <= nextsigJALR_EX;
			func3_EX <= nextfunc3_EX;
			func3_MEM <= nextfunc3_MEM;
			func7_EX <= nextfunc7_EX;


		end
		else begin
			I_MEM_ADDR <= PC;
		end
	end


	// PC State
	always @(*) begin
		if(SigStage[0]) nextPC_ID = PC;
		else nextPC_ID = PC_ID;

		if(SigStage[1]&(~LocalJump)) nextPC_EX = PC_ID;
		else nextPC_EX = PC_EX;

		if(SigStage[2]) nextPC_MEM = PC_EX;
		else nextPC_MEM = PC_MEM;

		if(SigStage[3]) nextPC_WB = PC_MEM;
		else nextPC_WB = PC_WB;

        if(InitForBranch) nextIR_ID = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
		else if(SigStage[0]|nextSigStage[1]) nextIR_ID = IR;
		else if(change) nextIR_ID = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
		else if(init) nextIR_ID = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
		else if(~tmp) nextIR_ID = IR_ID;
		else nextIR_ID = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;

        if(InitForBranch) begin
			nextIR_EX = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigOP_EX = 1'bx;
			nextsigOPImm_EX = 1'bx;
			nextsigLoad_EX = 1'bx;
			nextsigStore_EX = 1'bx;
			nextsigBranch_EX = 1'bx;
			nextsigJump_EX = 1'bx;
			nextsigJALR_EX = 1'bx;
			nextfunc3_EX = 3'bxxx;
			nextfunc7_EX = 7'bxxxxxxx;
		end
		else if(Change_BTB) begin 
			nextIR_EX = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigOP_EX = 1'bx;
			nextsigOPImm_EX = 1'bx;
			nextsigLoad_EX = 1'bx;
			nextsigStore_EX = 1'bx;
			nextsigBranch_EX = 1'bx;
			nextsigJump_EX = 1'bx;
			nextsigJALR_EX = 1'bx;
			nextfunc3_EX = 3'bxxx;
			nextfunc7_EX = 7'bxxxxxxx;
		end
		else if(SigStage[1]) begin
			nextIR_EX = IR_ID;
			nextsigOP_EX = sigOP_ID;
			nextsigOPImm_EX = sigOPImm_ID;
			nextsigLoad_EX = sigLoad_ID;
			nextsigStore_EX = sigStore_ID;
			nextsigBranch_EX = sigBranch_ID;
			nextsigJump_EX = sigJump_ID;
			nextsigJALR_EX = sigJALR_ID;
			nextfunc3_EX = func3_ID;
			nextfunc7_EX = func7_ID;
		end
		else if(init) begin
			nextIR_EX = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigOP_EX = 1'bx;
			nextsigOPImm_EX = 1'bx;
			nextsigLoad_EX = 1'bx;
			nextsigStore_EX = 1'bx;
			nextsigBranch_EX = 1'bx;
			nextsigJump_EX = 1'bx;
			nextsigJALR_EX = 1'bx;
			nextfunc3_EX = 3'bxxx;
			nextfunc7_EX = 7'bxxxxxxx;
		end
		else begin
			nextIR_EX = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigOP_EX = 1'bx;
			nextsigOPImm_EX = 1'bx;
			nextsigLoad_EX = 1'bx;
			nextsigStore_EX = 1'bx;
			nextsigBranch_EX = 1'bx;
			nextsigJump_EX = 1'bx;
			nextsigJALR_EX = 1'bx;
			nextfunc3_EX = 3'bxxx;
			nextfunc7_EX = 7'bxxxxxxx;
		end

		if(SigStage[2]) begin
			nextIR_MEM = IR_EX;
			nextsigLoad_MEM = sigLoad_EX;
			nextsigStore_MEM = sigStore_EX;
			nextsigBranch_MEM = sigBranch_EX;
			nextfunc3_MEM = func3_EX;
		end
		else if(init) begin
			nextIR_MEM = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigLoad_MEM = 1'bx;
			nextsigStore_MEM = 1'bx;
			nextsigBranch_MEM = 1'bx;
			nextfunc3_MEM = 3'bxxx;
		end
		else begin
			nextIR_MEM = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigLoad_MEM = 1'bx;
			nextsigStore_MEM = 1'bx;
			nextsigBranch_MEM = 1'bx;
			nextfunc3_MEM = 3'bxxx;
		end

		if(SigStage[3]) begin
			nextIR_WB = IR_MEM;
			nextsigLoad_WB = sigLoad_MEM;
			nextsigStore_WB = sigStore_MEM;
			nextsigBranch_WB = sigBranch_MEM;
		end
		else if(init) begin
			nextIR_WB = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigLoad_WB = 1'bx;
			nextsigStore_WB = 1'bx;
			nextsigBranch_WB = 1'bx;
		end
		else begin
			nextIR_WB = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			nextsigLoad_WB = 1'bx;
			nextsigStore_WB = 1'bx;
			nextsigBranch_WB = 1'bx;
		end

		if(SigStage[3]) ALUOut_temp = ALUOut_MEM;
		if(nextSigStage[3]) A_temp = A_EX;
		if(nextSigStage[3]) B_temp = B_EX;

	end

	// Control State
	always @(*) begin
		if(SigStage[0]) begin //IF stage
			IRWrite = 1;
			PCSource = 7;
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

	// Forward Unit, Signal Generator
	always @(*) begin
		if(Harzard_Level) begin
			ForwardA = 0;
			ForwardB = 0;
			if((IR[19:15]==IR_ID[11:7])|(IR[19:15]==IR_EX[11:7])|(IR[19:15]==IR_MEM[11:7])|(IR[19:15]==IR_WB[11:7])|(IR[24:20]==IR_ID[11:7])|(IR[24:20]==IR_EX[11:7])|(IR[24:20]==IR_MEM[11:7])|(IR[24:20]==IR_WB[11:7])) begin
				Gen_Danger = 1;
			end
			else begin
				Gen_Danger = 0;
				case(HarzardCounter)
					3'b001 : begin
							nextHarzardCounter = 0;
							nextHarzard_Level = 0;
					end
					3'b010 : begin
							nextHarzardCounter = 1;
					end
					3'b011 : begin
							nextHarzardCounter = 2;
					end
				endcase
			end
		end
		else begin
			ForwardA = 0;
			ForwardB = 0;
			Gen_Danger = 0;
			if((IR[19:15]==IR_MEM[11:7])) begin
				if((IR_MEM[6:0] == 7'b0110011)|(IR_MEM[6:0] == 7'b0000011)|(IR_MEM[6:0] == 7'b0010011)) begin
					if(IR[19:15]==IR_MEM[11:7]) ForwardA = 1;
					nextHarzard_Level = 1;
					nextHarzardCounter = 1;
					Gen_Danger = 0;
				end
				else begin
					Gen_Danger = 1;
				end
			end
			else if((IR[19:15]==IR_EX[11:7])) begin
				if((IR_EX[6:0] == 7'b0110011)|(IR_EX[6:0] == 7'b0010011)) begin
					if(IR[19:15]==IR_EX[11:7]) ForwardA = 2;
					Gen_Danger = 0;
					nextHarzard_Level = 1;
					nextHarzardCounter = 2;
				end
				else begin
					Gen_Danger = 1;
				end
			end
			else if((IR[19:15]==IR_ID[11:7])) begin
				if((IR_ID[6:0] == 7'b0110011)|(IR_ID[6:0] == 7'b0010011)) begin
					if(IR[19:15]==IR_ID[11:7]) ForwardA = 3;
					Gen_Danger = 0;
					nextHarzard_Level = 1;
					nextHarzardCounter = 3;
				end
				else begin
					Gen_Danger = 1;
				end
			end
			if((IR[24:20]==IR_ID[11:7])|(IR[24:20]==IR_EX[11:7])|(IR[24:20]==IR_MEM[11:7])) begin
				Gen_Danger = 1;
			end
		end
	end

    // BRANCH Precditor
    always @(*) begin
		if(check2) begin
			nextcheck2 = 0;
		end
        else if(Active_BTB&(~Finish_BTB)) begin
			nextcheck2 = 1;
            InitForBranch = 0;
            if(PC == BTB[23:12]) begin
                FirstLoop = 0;
                case(BTB[25])
                    1'b1 : begin
                        nextPC = BTB[11:0];
                    end
                    1'b0 : begin
                        nextPC = PC + 4;
                    end
                endcase
            end
            else begin
                FirstLoop = 1;
                nextPC = PC + 4;
				partition2 = PC;
				nextBTB = {2'b10, partition2, nextPC};
            end
        end
        else if(Change_BTB) begin
            case(BTB[25:24])
                2'b11 : begin
                    if(taken) partition1 = 2'b11;
                    else partition1 = 2'b10;
                end
                2'b10 : begin
                    if(taken) partition1 = 2'b11;
                    else partition1 = 2'b01;
                end
                2'b01 : begin
                    if(taken) partition1 = 2'b10;
                    else partition1 = 2'b00;
                end
                2'b00 : begin
                    if(taken) partition1 = 2'b01;
                    else partition1 = 2'b00;
                end
            endcase
            nextBTB = {partition1,partition2,BranchPointer};
            if(~success) InitForBranch = 1;
            else InitForBranch = 0; 
        end
        else begin
            InitForBranch = 0;
        end
    end

	//Stage State
	always @(*) begin
	
		sigOP_ID = (IR_ID[6:0] == 7'b0110011);
		sigOPImm_ID = (IR_ID[6:0] == 7'b0010011);
		sigLoad_ID = (IR_ID[6:0] == 7'b0000011);
		sigStore_ID = (IR_ID[6:0] == 7'b0100011);
		sigBranch_ID = (IR_ID[6:0]==7'b1100011);
		sigJump_ID = (IR_ID[6:0]==7'b1101111);
		sigJALR_ID = (IR_ID[6:0]==7'b1100111);
		func3_ID = IR_ID[14:12];
		func7_ID = IR_ID[31:25];
		RD_ID = IR_ID[11:7];

		if(sigBranch_ID|sigJump_ID|sigJALR_ID) begin
			tmp = 0;
		end
		else begin
			tmp = 1;
		end
		if((IR_ID[6:0]==7'b1101111)|(IR_ID[6:0]==7'b1100011)) begin
			tmp2 = 0;
		end
		else begin
			tmp2 = 1;
		end
		if(sigJALR_EX|sigJump_EX|sigBranch_EX) begin
			LocalJump = 1;
		end
		else begin
			LocalJump = 0;
		end
		if((~free)&Gen_Danger) begin
			danger = 1;
		end
		else begin
			danger = 0;
		end
		if(sigBranch_ID) begin
			Finish_BTB = 1;
		end
		else begin
			Finish_BTB = 0;
		end

		treeout = (IR[6:0]==7'b1101111)|(IR[6:0]==7'b1100111); // Jump, JALR
		if((I_MEM_DI[6:0]==7'b1100011)) begin
			Active_BTB = 1;
		end
		else begin
			Active_BTB = 0;
		end
		if(sigBranch_EX) begin
			Change_BTB = 1;
		end
		else begin
			Change_BTB = 0;
		end

		if((danger&tmp2)|check) begin
			change = 0;
			case(Counter) 
				3'b001 : begin
					nextcheck = 1;
					nextSigStage[0] = 0;
					nextSigStage[1] = 0;
					nextSigStage[2] = SigStage[1];
					nextSigStage[3] = SigStage[2];
					nextSigStage[4] = SigStage[3];
					nextCounter = 2;
					nextfree = 1;
				end
				3'b010 : begin
					nextcheck = 1;
					nextSigStage[0] = 0;
					nextSigStage[1] = 0;
					nextSigStage[2] = 0;
					nextSigStage[3] = SigStage[2];
					nextSigStage[4] = SigStage[3];
					nextCounter = 3;
					nextfree = 1;
				end
				3'b011 : begin
					nextcheck = 1;
					nextSigStage[0] = 0;
					nextSigStage[1] = 0;
					nextSigStage[2] = 0;
					nextSigStage[3] = 0;
					nextSigStage[4] = SigStage[3];
					nextCounter = 4;
					nextfree = 1; 
				end
				3'b100 : begin
					nextcheck = 0;
					if(~tmp2) nextSigStage[0] = 0;
					else nextSigStage[0] = 1;
					nextSigStage[1] = 1;
					nextSigStage[2] = 0;
					nextSigStage[3] = 0;
					nextSigStage[4] = 0;
					nextCounter = 1;
					nextHarzard_Level = 0;
					nextHarzardCounter = 0;
					nextfree = 0;
				end
			endcase
		end

		else begin
			nextcheck = 0;
			if((IR_ID[6:0]==7'b1101111)) begin  //opcode == Jump at ID stage
				case(Counter) 
					3'b001 : begin
						IRWrite = 0;
						nextSigStage[0] = 0;
						nextSigStage[1] = 0;
						nextSigStage[2] = 1; 
						nextSigStage[3] = SigStage[2]; 
						nextSigStage[4] = SigStage[3]; 
						nextCounter = 2;
						nextfree = 1;
					end
					3'b010 : begin
						nextSigStage[0] = 1;
						nextSigStage[1] = 0;
						nextSigStage[2] = 0;
						nextSigStage[3] = 1; 
						nextSigStage[4] = SigStage[3];
						nextCounter = 1;
						nextfree = 0;
						change = 1;
					end
				endcase
			end

			else if((IR_ID[6:0]==7'b1100111)) begin //opcode == JALR at ID stage
				case(Counter) 
					3'b001 : begin
						IRWrite = 0;
						nextSigStage[0] = 0;
						nextSigStage[1] = 0;
						nextSigStage[2] = 1;
						nextSigStage[3] = SigStage[2];
						nextSigStage[4] = SigStage[3];
						nextCounter = 2;
						nextfree = 1;
					end
					3'b010 : begin
						nextSigStage[0] = 1;
						nextSigStage[1] = 0;
						nextSigStage[2] = 0;
						nextSigStage[3] = 1;
						nextSigStage[4] = SigStage[3];
						nextCounter = 1;
						nextfree = 0;
						change = 1;
					end
				endcase
			end
			else begin
				change = 0;
				if(treeout) begin
					nextSigStage[0] = 0;
					nextfree = 1;
				end
				else begin 
					nextSigStage[0] = 1;
					nextfree = 0;
				end
				if(Change_BTB) begin
					if(~success) begin
						nextSigStage[1] = 0;
						nextSigStage[2] = 0;
					end
					else begin
						nextSigStage[1] = SigStage[0];
						nextSigStage[2] = SigStage[1];
					end
				end
				else begin
					nextSigStage[1] = SigStage[0];
					nextSigStage[2] = SigStage[1];
				end
				nextSigStage[3] = SigStage[2];
				nextSigStage[4] = SigStage[3];
				nextCounter = 1;
			end

		end

		if(nextSigStage[0]) PCWrite = 1;
		else PCWrite = 0;
	end

	// For WB Stage 
	assign RF_WE = SigStage[4]&(( IR_WB[6:0] == 7'b1101111 )| ( IR_WB[6:0] == 7'b1100111 ) |( IR_WB[6:0] == 7'b0000011 ) |( IR_WB[6:0] == 7'b0110011 ) | ( IR_WB[6:0] == 7'b0010011 ));

	// Terminate the Program __ Signal
	assign HALT = regHALT;
	always @ (*) begin
		if((IR_WB == 32'h00008067)& (RF_RD1 == 32'h0000000c)) begin // 
			regHALT = 1;
		end
	end

	//1. Instruction Fetch 
	always @(*) begin
		if(IRWrite) begin
			IR = I_MEM_DI; // copy input to the Instruction Regsiter
			if(((~Active_BTB))) nextPC = PC + 4; // If the next instruction doesn't jump, branch,then nextPC = PC+4
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

	assign RF_RA1 = rs1;
	assign RF_RA2 = rs2;
	assign RF_WA1 = rd;

	always @(*) begin
		if(IDWrite)begin
			rs1 = IR_ID[19:15];
			rs2 = IR_ID[24:20];
		end
	end

	always @(*) begin
		if(SigStage[4]) begin
			rd = IR_WB[11:7];
		end
	end

	// Get Register Data (at ID stage)
	always @(*) begin
		if(IDWrite) begin
			case(ForwardA_ID)
				3'b000 : begin
					A_ID = RF_RD1;
				end
				3'b001 : begin
					A_ID = regWD;
				end
				3'b010 : begin
					A_ID = ALUOut_MEM;
				end
				3'b011 : begin
					A_ID = ALUOut;
				end
			endcase
			case(ForwardB_ID)
				3'b000 : begin
					B_ID = RF_RD2;
				end
				3'b001 : begin
					B_ID = regWD;
				end
				3'b010 : begin
					B_ID = ALUOut_MEM;
				end
				3'b011 : begin
					B_ID = ALUOut;
				end
			endcase
		end
	end

	// 3. Execution Stage
	always @(*) begin
		if(ALUOp) begin
			oprnd1 = A_EX;
			oprnd2 = B_EX;	
			if(sigOP_EX) begin 
				success = 0;
				PCBranch = 0;
				case(func3_EX) 
					3'b000: begin
						if(func7_EX == 7'b0000000) begin // ADD 
							result = oprnd1+oprnd2;
						end
						if(func7_EX == 7'b0100000) begin // SUB 
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
							result = (oprnd1 >> oprnd2[4:0]) | (oprnd1[31] << 31); 
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
			else if(sigLoad_EX) begin // Load 
				result = oprnd1 + immI_EX;
				PCBranch = 0;
				success = 0;
			end
			else if (sigStore_EX) begin // Store 
				result = oprnd1 + immS_EX;
				PCBranch = 0;
				success = 0;
			end
			else if(sigJALR_EX) begin // JALR
				result = ((oprnd1 + immI_EX)>>1)<<1;
				PCSource = 3;
				PCBranch = 0;
				success = 0;
			end
			else if(sigJump_EX) begin // Jump 
				PCSource = 2;
				result = PC_EX + 4;
				PCBranch = 0;
				success = 0;
			end
			else if(sigOPImm_EX) begin // Itype 
				success = 0;
				case(func3_EX) // IR_EX[14:12]
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
						if(func7_EX == 7'b0000000) begin // SRL
							result = oprnd1 >> immI_EX[4:0];
						end
						if(func7_EX == 7'b0100000) begin // SRA 
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
				PCBranch = 0;
			end
			else begin // Branch
				result = PC_EX + immB_EX;
                BranchPointer = PC_EX + immB_EX;
				case(func3_EX)
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
                taken = PCSource;
                if(FirstLoop) begin
                    if(PCSource[0]) success = 0;
                    else success = 1;
                end
                else begin
                    if(BTB[25]==PCSource[0]) success = 1;
                    else success = 0;
                end
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
        if(((~Active_BTB)&(~success))) begin
            case(PCSource) // Decide the nextPC
                3'b001 : begin //Branch (True case)
                nextPC = ALUOut[11:0];
                end
                3'b011 : begin 
                nextPC = A_EX&12'hFFF; //JALR
                end
                3'b010 : begin
                nextPC = (immJ_EX + PC_EX)&12'hFFF; // Jump
                end
                3'b000 : begin
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
	assign D_MEM_BE = regBE_MEM;
	reg[2:0] temp;

	always @ (*) begin
		if(SigStage[3]) begin
			temp = func3_MEM; 
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
			if(sigLoad_MEM) begin 
				regMemOutput_MEM = D_MEM_DI;
				
				if(IR_MEM[14:12] == 3'b000) begin // lb
					if(D_MEM_DI[7] == 1'b1) begin
						regMemOutput_MEM = {24'b111111111111111111111111, D_MEM_DI[7:0]};
					end
					else begin
						regMemOutput_MEM = {24'b000000000000000000000000, D_MEM_DI[7:0]};
					end
				end
				if(IR_MEM[14:12] == 3'b001) begin // lh
					if(D_MEM_DI[15] == 1'b1) begin
						regMemOutput_MEM = {16'b1111111111111111, D_MEM_DI[15:0]};
					end
					else begin
						regMemOutput_MEM = {16'b0000000000000000, D_MEM_DI[15:0]};
					end
				end
				
			end
		end
	end

	//5. Write Back Stage
	
	assign RF_WD = regWD;

	always @(*) begin
		if(SigStage[4]) begin
			if(sigLoad_WB) begin 
				regWD = regMemOutput_WB;
			end
			else if(sigBranch_WB) begin 
				regWD = SAVOR;
			end
			else if(RegWrite) begin
				regWD = ALUOut_WB;
			end
		end
	end

endmodule //
