module ALU (
    input wire activate,
    input wire [3:0] op, // funct3
    input wire [6:0] subop, // funct7
    input wire [31:0] op1,
    input wire [31:0] op2,
    output wire [31:0] res

    );

    reg [31:0] result;
    assign res = result;


    always @ (*) begin
        if(activate) begin
            case(op)
                3'b000: begin // add or sub
                    if(subop == 7'b0000000) result = op1 + op2; //ADD
                    if(subop == 7'b0100000) result = op1 - op2; //SUB
                    else result = op1 + op2; // if addi
                    //$display("result, ", result);
                end
                3'b001: begin // SLL
                    result = op1 << op2[4:0];
                end
                3'b010: begin // SLT
                    result = $signed(op1) < $signed(op2);
                end
                3'b011: begin // SLTU
                    result = op1 < op2;
                end
                3'b100: begin // XOR
                    result = op1 ^ op2;
                end
                3'b101: begin // SRL or SRA
                    if(subop == 7'b0000000) begin // SRL
                        result = (op1 >> op2[4:0]);
                    end
                    if(subop == 7'b0100000) begin //SRA
                        result = (op1 >> op2[4:0]); // modify it!
                    end
                end
                3'b110: begin // OR
                    result = op1 | op2;
                end
                3'b111: begin // AND
                    result = op1 & op2;
                end
            endcase
        end
    end



endmodule