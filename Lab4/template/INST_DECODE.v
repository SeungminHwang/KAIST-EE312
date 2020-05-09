module INST_DECODE(
    input wire [31:0] INST,
    input wire activate, // fix

    //for R-type;
    output wire [6:0] opcode,
	output wire [4:0] rs1,
	output wire [4:0] rs2,
	output wire [4:0] rd,
	output wire [2:0] funct3,
	output wire [6:0] funct7,

    output wire [31:0] immI, // immediate for I
	output wire [31:0] immS, // immediate for S
	output wire [31:0] immB, // immediate for B
	output wire [31:0] immU, // immediate for U
	output wire [31:0] immJ, // immediate for J

    //control signal
    output wire sigOpIMM,
	output wire sigOP,
	output wire sigJAL,
	output wire sigJALR,
	output wire sigBRANCH,
	output wire sigLOAD,
	output wire sigSTORE,

    output wire sigALUSrc,
	output wire sigMemToReg,

    output wire RF_WE,
	output wire [4:0] RF_RA1, // Read reg. 1
	output wire [4:0] RF_RA2, // Read reg. 2
	output wire [4:0] RF_WA1, // Write Addr.
    input wire [31:0] RF_RD1, //Read Data 1
	input wire [31:0] RF_RD2, //Read Data 2
	//output wire [31:0] RF_WD, // Write Data
    output wire [31:0] oprnd2,
    output wire [31:0] oprnd1,

    output wire HALT,

    input wire writeEn

    );

    reg regHALT;



    reg [6:0] reg_opcode;
    reg [4:0] reg_rs1;
    reg [4:0] reg_rs2;
    reg [4:0] reg_rd;
    reg [2:0] reg_funct3;
    reg [6:0] reg_funct7;
    reg [31:0] reg_immI;
    reg [31:0] reg_immS;
    reg [31:0] reg_immB;
    reg [31:0] reg_immJ;
    reg [31:0] reg_immU;
    reg reg_sigOpIMM;
    reg reg_sigOP;
    reg reg_sigJAL;
    reg reg_sigJALR;
    reg reg_sigBRANCH;
    reg reg_sigLOAD;
    reg reg_sigSTORE;
    reg reg_sigALUSrc;
    reg reg_sigMemToReg;
    reg reg_RF_WE;
    reg [4:0] reg_RF_RA1;
    reg [4:0] reg_RF_RA2;
    reg [4:0] reg_RF_WA1;
    reg [31:0] reg_oprnd2;
    reg [31:0] reg_oprnd1;



    assign opcode = reg_opcode;
    assign rs1 = reg_rs1;
    assign rs2 = reg_rs2;
    assign rd = reg_rd;
    assign funct3 = reg_funct3;
    assign funct7 = reg_funct7;
    assign immI = reg_immI;
    assign immS = reg_immS;
    assign immB = reg_immB;
    assign immJ = reg_immJ;
    assign immU = reg_immU;
    assign sigOpIMM = reg_sigOpIMM;
    assign sigOP = reg_sigOP;
    assign sigJAL = reg_sigJAL;
    assign sigJALR = reg_sigJALR;
    assign sigBRANCH = reg_sigBRANCH;
    assign sigLOAD = reg_sigLOAD;
    assign sigSTORE = reg_sigSTORE;
    assign sigALUSrc = reg_sigALUSrc;
    assign sigMemToReg = reg_sigMemToReg;
    assign RF_WE = reg_RF_WE;
    assign RF_RA1 = reg_RF_RA1;
    assign RF_RA2 = reg_RF_RA2;
    assign RF_WA1 = reg_RF_WA1;
    assign oprnd2 = reg_oprnd2;
    assign oprnd1 = reg_oprnd1;

    assign HALT = regHALT;


    //fix
    always @ (*) begin
        $display("I_MEM_DI: %x", INST);
        if(activate) begin
            //$display("isID Yeah!");
            reg_opcode = INST[6:0];
            reg_rs1 = INST[19:15];
            reg_rs2 = INST[24:20];
            reg_rd = INST[11:7];
            reg_funct3 = INST[14:12];
            reg_funct7 = INST[31:25];

            reg_RF_RA1 = rs1;
            reg_RF_RA2 = rs2;
            reg_RF_WA1 = rd;

            if(INST[31] == 1'b1) begin
                reg_immI = {21'b111111111111111111111, INST[30:25], INST[24:21], INST[20]};
                reg_immS = {20'b11111111111111111111,INST[31], INST[30:25], INST[11:8], INST[7]};
                reg_immB = {19'b1111111111111111111, INST[31], INST[7], INST[30:25], INST[11:8], 1'b0};
                reg_immJ = {11'b11111111111, INST[31], INST[19:12], INST[20], INST[30:25], INST[24:21], 1'b0};
            end
            else begin
                reg_immI = {21'b000000000000000000000, INST[30:25], INST[24:21], INST[20]};
                reg_immS = {20'b00000000000000000000,INST[31], INST[30:25], INST[11:8], INST[7]};
                reg_immB = {19'b0000000000000000000, INST[31], INST[7], INST[30:25], INST[11:8], 1'b0};
                reg_immJ = {11'b00000000000, INST[31], INST[19:12], INST[20], INST[30:25], INST[24:21], 1'b0};
            end
            
            
            
            reg_immU = {INST[31], INST[30:20], INST[19:12], 12'b000000000000};
            

            reg_sigOpIMM =  (opcode == 7'b0010011); // I type
            reg_sigOP =  (opcode == 7'b0110011); //R type
            reg_sigJAL =  (opcode == 7'b1101111); // J type
            reg_sigJALR =  ( opcode == 7'b1100111 ); // Itype
            reg_sigBRANCH =  (opcode == 7'b1100011); // B type
            reg_sigLOAD =  (opcode == 7'b0000011); // I type
            reg_sigSTORE =  (opcode == 7'b0100011); // S type

            reg_sigALUSrc =  (sigOP) | (sigBRANCH); // 1 for "use RF_RD1" 0 for immediate
            reg_sigMemToReg =  sigLOAD;

            reg_RF_WE = ((sigJAL) | (sigJALR) | (sigLOAD) | (sigOP) | (sigOpIMM));//&writeEn;
            

            //$display("isID Yeah!");
            //HALT
            if((INST == 32'h00008067) & (RF_RD1 == 32'h0000000c)) begin
                regHALT = 1;
            end

            //mk oprnd2
            //$display("op, opimm", sigOP, sigOpIMM, INST, opcode);
            if(reg_sigOP) reg_oprnd2 = RF_RD2;
            else if(reg_sigOpIMM) reg_oprnd2 = immI;
            reg_oprnd1 = RF_RD1;

            //$display("oprnd2: ", oprnd2);

        end
    end

endmodule