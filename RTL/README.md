# Montgomery Multiplier Design Files

## RTL Designs

- `mont_gen_param.v`   - CIOS algorithm (274 cycles)
- `mont_ultra_param.v` - Parallel implementation (19 cycles)  

## Testbenches (test these with the i/o versions)

- `mont_gen_tb.v`
- `mont_ultra_tb.v`

## Synthesis Results (Alveo U250, 222 MHz)

| Design         | Cycles | Time/Op |
|----------------|--------|---------|
| Sequential     |  274   | 1.23 μs |
| Ultra-Parallel |   19   | 85.5 ns |
