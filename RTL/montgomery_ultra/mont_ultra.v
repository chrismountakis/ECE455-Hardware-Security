// Ultra-Parallel Montgomery Multiplier
// Computes: Mont(a, b) = a * b * R^(-1) mod N
// where R = 2^SIZE
// Latency: 19 cycles for 1024-bit
// 
// PARAMETERS:
//   - SIZE: total bit width (must be multiple of WORD)
//   - WORD: word size in bits (typically 64)
//
// INPUTS:
//   - a, b: operands (must be < N)
//   - n: the modulus (must be odd)
//   - n_prime: precomputed -N^(-1) mod 2^WORD
module Montgomery #(
    parameter SIZE = 1024,
    parameter WORD = 64
)(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [SIZE-1:0] a,
    input wire [SIZE-1:0] b,
    input wire [SIZE-1:0] n,
    input wire [WORD-1:0] n_prime,
    output reg [SIZE-1:0] result,
    output reg done
);

localparam NUM_WORDS = SIZE / WORD;
localparam CNT_WIDTH = $clog2(NUM_WORDS);

// FSM states
parameter [1:0] IDLE    = 2'b00,
                FIRST   = 2'b01,        // First iteration (compute initial mi)
                PROCESS = 2'b10,        // Process + compute next mi
                FINAL   = 2'b11;

reg [1:0] state, nxt_state;

// Datapath registers
reg [SIZE-1:0] a_reg, b_reg, n_reg;
reg [WORD-1:0] n_prime_reg;
reg [SIZE+WORD:0] t;                    // t register         
reg [CNT_WIDTH-1:0] i;                  // iteration counter
reg [WORD-1:0] ui, mi;                  // current ui and mi


// ============================================================
// PARALLEL MULTIPLICATIONS 
// ============================================================
wire [2*WORD-1:0] prod_uib [0:NUM_WORDS-1];
wire [2*WORD-1:0] prod_min [0:NUM_WORDS-1];

genvar k;
generate
    for (k = 0; k < NUM_WORDS; k = k + 1) begin : mult_gen
        assign prod_uib[k] = ui * b_reg[k*WORD +: WORD];
        assign prod_min[k] = mi * n_reg[k*WORD +: WORD];
    end
endgenerate

// ============================================================
// CARRY-SAVE ADDITION
// ============================================================
wire [WORD+3:0] sum [0:NUM_WORDS-1];
wire [WORD:0] carry [0:NUM_WORDS];

assign carry[0] = 0;

generate
    for (k = 0; k < NUM_WORDS; k = k + 1) begin : carry_gen
        // sum = t_word + prod_uib_low + prod_min_low + carry
        assign sum[k] = {3'b0, t[k*WORD +: WORD]} +
                        {3'b0, prod_uib[k][WORD-1:0]} +
                        {3'b0, prod_min[k][WORD-1:0]} +
                        {2'b0, carry[k]};
        
        // Next carry = prod_uib_high + prod_min_high + sum_carry
        assign carry[k+1] = {1'b0, prod_uib[k][2*WORD-1:WORD]} +
                                  {1'b0, prod_min[k][2*WORD-1:WORD]} +
                                  {{(WORD-3){1'b0}}, sum[k][WORD+3:WORD]};
    end
endgenerate

// Final carry
wire [WORD:0] t_upper_new = t[SIZE+WORD:SIZE] + carry[NUM_WORDS];

// ============================================================
// BUILD NEW t (before shift)
// ============================================================
wire [SIZE+WORD:0] t_new;
generate
    if (NUM_WORDS == 16) begin : t_new_16                       // N: 1024 bits
        assign t_new = {t_upper_new,
                       sum[15][WORD-1:0], sum[14][WORD-1:0],
                       sum[13][WORD-1:0], sum[12][WORD-1:0],
                       sum[11][WORD-1:0], sum[10][WORD-1:0],
                       sum[9][WORD-1:0],  sum[8][WORD-1:0],
                       sum[7][WORD-1:0],  sum[6][WORD-1:0],
                       sum[5][WORD-1:0],  sum[4][WORD-1:0],
                       sum[3][WORD-1:0],  sum[2][WORD-1:0],
                       sum[1][WORD-1:0],  sum[0][WORD-1:0]};
    end else if (NUM_WORDS == 8) begin : t_new_8                // N: 512 bits
        assign t_new = {t_upper_new,
                       sum[7][WORD-1:0], sum[6][WORD-1:0],
                       sum[5][WORD-1:0], sum[4][WORD-1:0],
                       sum[3][WORD-1:0], sum[2][WORD-1:0],
                       sum[1][WORD-1:0], sum[0][WORD-1:0]};
    end else if (NUM_WORDS == 32) begin : t_new_32              // N: 2048 bits
        assign t_new = {t_upper_new,
                       sum[31][WORD-1:0], sum[30][WORD-1:0], sum[29][WORD-1:0], sum[28][WORD-1:0],
                       sum[27][WORD-1:0], sum[26][WORD-1:0], sum[25][WORD-1:0], sum[24][WORD-1:0],
                       sum[23][WORD-1:0], sum[22][WORD-1:0], sum[21][WORD-1:0], sum[20][WORD-1:0],
                       sum[19][WORD-1:0], sum[18][WORD-1:0], sum[17][WORD-1:0], sum[16][WORD-1:0],
                       sum[15][WORD-1:0], sum[14][WORD-1:0], sum[13][WORD-1:0], sum[12][WORD-1:0],
                       sum[11][WORD-1:0], sum[10][WORD-1:0], sum[9][WORD-1:0],  sum[8][WORD-1:0],
                       sum[7][WORD-1:0],  sum[6][WORD-1:0],  sum[5][WORD-1:0],  sum[4][WORD-1:0],
                       sum[3][WORD-1:0],  sum[2][WORD-1:0],  sum[1][WORD-1:0],  sum[0][WORD-1:0]};
    end else begin : t_new_general
        // Generic case (less efficient but works for any NUM_WORDS)
        wire [(NUM_WORDS*WORD)-1:0] t_lower_new;
        for (k = 0; k < NUM_WORDS; k = k + 1) begin
            assign t_lower_new[(NUM_WORDS-k-1)*WORD +: WORD] = sum[k][WORD-1:0];
        end
        assign t_new = {t_upper_new, t_lower_new};
    end
endgenerate

// Shift right by WORD bits
wire [SIZE+WORD:0] t_shifted = {{WORD{1'b0}}, t_new[SIZE+WORD:WORD]};

// ============================================================
// PIPELINED mi FOR NEXT ITERATION
// ============================================================
// Next iteration will have sum[1] as new t[0] after shift
wire [WORD-1:0] ui_next = a_reg[(i+1)*WORD +: WORD];
wire [WORD-1:0] t0_after_shift = sum[1][WORD-1:0];  // This becomes new t[0]
wire [2*WORD-1:0] ui_next_times_b0 = ui_next * b_reg[WORD-1:0];
wire [WORD-1:0] mi_next = ((t0_after_shift + ui_next_times_b0[WORD-1:0]) * n_prime_reg);

// Initial mi (when t=0)
wire [2*WORD-1:0] ui0_times_b0 = a_reg[WORD-1:0] * b_reg[WORD-1:0];
wire [WORD-1:0] mi_initial = (ui0_times_b0[WORD-1:0] * n_prime_reg);

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
        IDLE:    if (start) nxt_state = FIRST;
        FIRST:   nxt_state = PROCESS;
        PROCESS: if (i == NUM_WORDS - 1) nxt_state = FINAL;
        FINAL:   nxt_state = IDLE;
    endcase
end

// ============================================================
// DATAPATH
// ============================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        a_reg       <= 0;
        b_reg       <= 0;
        n_reg       <= 0;
        n_prime_reg <= 0;
        t           <= 0;
        i           <= 0;
        ui          <= 0;
        mi          <= 0;
        result      <= 0;
        done        <= 0;
    end else begin
        done <= 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    a_reg       <= a;
                    b_reg       <= b;
                    n_reg       <= n;
                    n_prime_reg <= n_prime;
                    t           <= 0;
                    i           <= 0;
                end
            end
            
            FIRST: begin
                // First iteration: compute initial ui and mi
                // t is still 0, so mi = (0 + a[0]*b[0]) * n_prime = a[0]*b[0]*n_prime
                ui <= a_reg[WORD-1:0];
                mi <= mi_initial;
            end
            
            PROCESS: begin
                // Update t with shifted result
                t <= t_shifted;
                i <= i + 1;
                
                // Pipeline: compute ui and mi for NEXT iteration
                // using the post-shift t[0] value (= sum[1])
                if (i < NUM_WORDS - 1) begin
                    ui <= ui_next;
                    mi <= mi_next;
                end
            end
            
            FINAL: begin
                // Final reduction
                if (t[SIZE] == 1'b1) begin
                    // t >= 2^SIZE, guaranteed t >= N
                    // t - N = t[SIZE-1:0] + (2^SIZE - N) = t[SIZE-1:0] + (~N + 1)
                    result <= t[SIZE-1:0] + (~n_reg + 1'b1);
                end else if (t[SIZE-1:0] >= n_reg) begin
                    result <= t[SIZE-1:0] - n_reg;
                end else begin
                    result <= t[SIZE-1:0];
                end
                done <= 1'b1;
            end
        endcase
    end
end
endmodule