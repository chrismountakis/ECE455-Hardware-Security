import gc
import secrets
import statistics
import time


def make_case(k_bits: int, profile: str):
    n = secrets.randbits(k_bits) | (1 << (k_bits - 1)) | 1
    base = secrets.randbelow(n)

    if profile == "best":
        exponent = 1 << (k_bits - 1)
    elif profile == "worst":
        exponent = (1 << k_bits) - 1
    elif profile == "average":
        half = k_bits // 2
        positions = {k_bits - 1}
        while len(positions) < half:
            positions.add(secrets.randbelow(k_bits))
        exponent = 0
        for p in positions:
            exponent |= 1 << p
    else:
        raise ValueError(profile)

    return n, base, exponent


def time_calls(fn, repeats, warmup=2):
    for _ in range(warmup):
        fn()

    samples = []
    gc_was_enabled = gc.isenabled()
    gc.disable()
    try:
        for _ in range(repeats):
            t0 = time.perf_counter()
            fn()
            t1 = time.perf_counter()
            samples.append(t1 - t0)
    finally:
        if gc_was_enabled:
            gc.enable()
    return samples


def us(seconds):
    return seconds * 1e6


def main():
    resolution_s = time.get_clock_info("perf_counter").resolution
    print(f"perf_counter resolution: {resolution_s * 1e9:.1f} ns\n")

    moduli_bits = [512, 1024, 2048]
    profiles = ["best", "average", "worst"]
    repeats_by_size = {512: 50, 1024: 50, 2048: 20}

    header = (f"{'bits':>5} {'case':>8} {'ones':>6} {'MontOps':>8} | "
              f"{'mean(us)':>10} {'min(us)':>10} {'max(us)':>10} {'stdev(us)':>10} "
              f"| {'min/res':>9}")
    print(header)
    print("-" * len(header))

    for k_bits in moduli_bits:
        repeats = repeats_by_size[k_bits]
        for profile in profiles:
            n, base, exponent = make_case(k_bits, profile)
            ones = bin(exponent).count("1")
            mont_ops = k_bits + ones + 2

            samples = time_calls(lambda: pow(base, exponent, n), repeats)
            mean_s = statistics.fmean(samples)
            min_s = min(samples)
            max_s = max(samples)
            stdev_s = statistics.stdev(samples) if len(samples) > 1 else 0.0

            print(f"{k_bits:>5} {profile:>8} {ones:>6} {mont_ops:>8} | "
                  f"{us(mean_s):>10.1f} {us(min_s):>10.1f} {us(max_s):>10.1f} "
                  f"{us(stdev_s):>10.1f} | {min_s / resolution_s:>9.0f}x")


if __name__ == "__main__":
    main()
