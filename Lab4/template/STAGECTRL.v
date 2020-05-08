module STAGECTRL(
    input wire [2:0] currentStage,
    input wire [6:0] opcode,
    output wire [2:0] nextStage,
    output wire PVSWriteEn
    );
//stage description
/*
0. IF
1. ID
2. EX
3. MEM
4. WB
*/
reg allowPVS;
reg [2:0] newStage;
assign PVSWriteEn = allowPVS;
assign nextStage = newStage;

always @ (*) begin
    $display("current stage: ", currentStage);
    case(currentStage)
        3'b000: begin // IF
            newStage = 3'b001;
            allowPVS = 0;
        end
        3'b001: begin // ID
            newStage = 3'b010;
            allowPVS = 0;
        end
        3'b010: begin //EX
            if (opcode == 7'b0110011 | opcode == 7'b0010011) begin // OP(Rtype) and OPIMM(Itype)
                newStage = 3'b100; // goto WB
                allowPVS = 0;
            end
            else if (opcode == 7'b0000011 | opcode == 7'b0100011) begin // LW or SW 
                newStage = 3'b011; //goto MEM
                allowPVS = 0;
            end
            else if (opcode == 7'b1100111) begin // JAL or JALR
                newStage = 3'b000;
                allowPVS = 1;
            end
            else begin // Branch or JAL
                newStage = 3'b000; // goto IF
                allowPVS = 1;
            end
        end
        3'b011: begin // MEM
            if(opcode == 7'b0000011) begin // LW
                newStage = 3'b100;// goto WB
                allowPVS = 0;
            end
            else if(opcode == 7'b0100011) begin // SW
                newStage = 3'b000;
                allowPVS = 1;
            end
        end
        3'b100: begin // WB
            newStage = 3'b001;
            allowPVS = 1;
        end
    endcase
end

endmodule