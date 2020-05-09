module ALU (
    input wire activate,
	input wire [2:0] op,
	input wire [6:0] subop,
    input wire [31:0] oprnd1,
    input wire [31:0] oprnd2,
    output wire [31:0] res
    );

    reg [31:0] result;
    assign res = result;
    always @ (*) begin
        //$display("op: ", op, oprnd1, oprnd2);
        if(activate) begin
            //$display("oprnd1, 2: ", oprnd1, oprnd2, subop);
            case(op)
                3'b000: begin // add or sub
                    if(subop == 7'b0000000) result = oprnd1 + oprnd2; //ADD
                    if(subop == 7'b0100000) result = oprnd1 - oprnd2; //SUB
                    else result = oprnd1 + oprnd2; // if addi
                    //$display("result, ", result);
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
                3'b101: begin // SRL or SRA
                    if(subop == 7'b0000000) begin // SRL
                        result = (oprnd1 >> oprnd2[4:0]);
                    end
                    if(subop == 7'b0100000) begin //SRA
                        result = (oprnd1 >> oprnd2[4:0]); // modify it!
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
    end



endmodule