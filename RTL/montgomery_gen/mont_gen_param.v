// Parameterized Montgomery Multiplier using CIOS algorithm
// Supports arbitrary odd modulus N up to SIZE bits
// Computes: Mont(a, b) = a * b * R^(-1) mod N
// where R = 2^SIZE
//
// PARAMETERS:
//   - SIZE: total bit width (must be multiple of WORD)
//   - WORD: word size in bits (typically 32, 64, etc.)
//   - a, b: operands (must be < N)
//   - n: the modulus (must be odd)
//   - n_prime: precomputed -N^(-1) mod 2^WORD

module Montgomery_Internal #(
    parameter SIZE = 1024,
    parameter WORD = 64,
    parameter [SIZE-1:0] a = 0,
    parameter [SIZE-1:0] b = 0,
    parameter [SIZE-1:0] n = 0,
    parameter [WORD-1:0] n_prime = 0
)(
    input wire clk,
    input wire reset,
    input wire start,
    output reg done  
);

localparam NUM_WORDS = SIZE / WORD;
localparam CNT_WIDTH = $clog2(NUM_WORDS);

// FSM States
parameter [1:0]  IDLE         = 2'b00,
                 CALC_MI      = 2'b01,
                 INNER_LOOP   = 2'b10,
                 FINAL_REDUCE = 2'b11;

// State register
reg [1:0] state, nxt_state;

// Datapath registers
reg [SIZE-1:0] a_reg, b_reg, n_reg;
reg [WORD-1:0] n_prime_reg;
reg [SIZE+WORD:0] t;                    // t register
reg [CNT_WIDTH-1:0] i, j;               // Loop counters
reg [WORD-1:0] ui, mi;                  // Current a_i and m_i
reg [WORD:0] carry;                     // Carry register

// INTERNAL RESULT REGISTER
reg [SIZE-1:0] result_internal;

// ============================================================
// COMBINATIONAL ARITHMETIC
// ============================================================
// Current words being processed
wire [WORD-1:0] b_word = b_reg[j*WORD +: WORD];
wire [WORD-1:0] n_word = n_reg[j*WORD +: WORD];
wire [WORD-1:0] t_word = t[j*WORD +: WORD];

// Multiplications
wire [2*WORD-1:0] prod_uib = ui * b_word;
wire [2*WORD-1:0] prod_min = mi * n_word;

// Addition: t_word + ui*b_word + mi*n_word + carry
wire [WORD+3:0] sum = {3'b0, t_word} + 
                      {3'b0, prod_uib[WORD-1:0]} + 
                      {3'b0, prod_min[WORD-1:0]} + 
                      {2'b0, carry};

// Next carry = high parts + sum carry
wire [WORD:0] next_carry = {1'b0, prod_uib[2*WORD-1:WORD]} +
                          {1'b0, prod_min[2*WORD-1:WORD]} +
                          {{(WORD-3){1'b0}}, sum[WORD+3:WORD]};

// For last word: compute shifted result
wire [SIZE+WORD:0] t_final_shifted = {{WORD{1'b0}}, 
                                     t[SIZE+WORD:SIZE] + next_carry, 
                                     sum[WORD-1:0], 
                                     t[SIZE-WORD-1:WORD]};

// ============================================================
// FSM
// ============================================================
always @(posedge clk or posedge reset) begin
    if (reset)
        state <= IDLE;
    else
        state <= nxt_state;
end

always @(*) begin
    nxt_state = state;
    
    case (state)
        IDLE:         if (start) nxt_state = CALC_MI;
        CALC_MI:      nxt_state = INNER_LOOP;
        INNER_LOOP:   if (j == NUM_WORDS - 1) begin
                          if (i == NUM_WORDS - 1)
                              nxt_state = FINAL_REDUCE;
                          else
                              nxt_state = CALC_MI;
                      end
        FINAL_REDUCE: nxt_state = IDLE;
        default:      nxt_state = IDLE;
    endcase
end

// ============================================================
// DATAPATH
// ============================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        a_reg      <= 0;
        b_reg      <= 0;
        n_reg      <= 0;
        n_prime_reg <= 0;
        t          <= 0;
        i          <= 0;
        j          <= 0;
        ui         <= 0;
        mi         <= 0;
        carry      <= 0;
        result_internal <= 0;  
        done       <= 0;
    end else begin
        done <= 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    a_reg      <= a;
                    b_reg      <= b;
                    n_reg      <= n;
                    n_prime_reg <= n_prime;
                    t          <= 0;
                    i          <= 0;
                    carry      <= 0;
                end
            end
            
            CALC_MI: begin
                ui    <= a_reg[i*WORD +: WORD];
                // mi = (t[WORD-1:0] + a_i * b_0) * n_prime mod 2^WORD
                mi    <= ((t[WORD-1:0] + a_reg[i*WORD +: WORD] * b_reg[WORD-1:0]) * n_prime_reg);
                j     <= 0;
                carry <= 0;
            end
            
            INNER_LOOP: begin
                if (j == NUM_WORDS - 1) begin
                    // Last word: update, add carry, and shift in one cycle
                    t <= t_final_shifted;
                    carry <= 0;
                    i <= i + 1;
                    j <= 0;
                end else begin
                    t[j*WORD +: WORD] <= sum[WORD-1:0];
                    carry <= next_carry;
                    j <= j + 1;
                end
            end
            
            FINAL_REDUCE: begin
                // t can be up to 2N-1, so t[SIZE] (bit SIZE) may be set
                // Store result INTERNALLY instead of outputting it
                if (t[SIZE] == 1'b1) begin
                    // t >= 2^SIZE, guaranteed t >= N
                    // t - N = t[SIZE-1:0] + (2^SIZE - N) = t[SIZE-1:0] + (~N + 1)
                    result_internal <= t[SIZE-1:0] + (~n_reg + 1'b1);
                end else if (t[SIZE-1:0] >= n_reg) begin
                    result_internal <= t[SIZE-1:0] - n_reg;
                end else begin
                    result_internal <= t[SIZE-1:0];
                end
                done <= 1'b1;
            end
        endcase
    end
end
endmodule
