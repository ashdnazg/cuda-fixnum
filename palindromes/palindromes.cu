#include <cstdio>
#include <cstring>
#include <cassert>
#include <cinttypes>

#include "fixnum/warp_fixnum.cu"
#include "array/fixnum_array.h"
#include "functions/modexp.cu"
#include "functions/multi_modexp.cu"
#include "modnum/modnum_monty_redc.cu"
#include "modnum/modnum_monty_cios.cu"

#include "uint256_t.h"

using namespace std;
using namespace cuFIXNUM;

template< typename fixnum >
struct add {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::add(s, a, b);
        r = s;
    }
};


template< typename fixnum >
struct add2 {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::add2(s, a, b);
        r = s;
    }
};

template< typename fixnum >
struct bitwise_and {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::bitwise_and(s, a, b);
        r = s;
    }
};

template< typename fixnum >
struct bitwise_xor {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::bitwise_xor(s, a, b);
        r = s;
    }
};

template< typename fixnum >
struct bitwise_or {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::bitwise_or(s, a, b);
        r = s;
    }
};



template< typename fixnum >
struct reverse_bits {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::reverse_bits(s, a);
        r = s;
    }
};

template< typename fixnum >
struct mul_lo {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::mul_lo(s, a, b);
        r = s;
    }
};

template< typename fixnum >
struct mul_wide {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum rr, ss;
        fixnum::mul_wide(ss, rr, a, b);
        r = ss;
    }
};

template< typename fixnum >
struct sqr_wide {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum rr, ss;
        fixnum::sqr_wide(ss, rr, a);
        r = ss;
    }
};

template< typename fixnum >
struct sqr_lo1 {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::mul_lo(s, a, a);
        r = s;
    }
};

template< typename fixnum >
struct sqr_lo2 {
    __device__ void operator()(fixnum &r, fixnum a, fixnum b) {
        fixnum s;
        fixnum::sqr_lo(s, a);
        r = s;
    }
};

template< typename modnum >
struct my_modexp {
    typedef typename modnum::fixnum fixnum;

    __device__ void operator()(fixnum &z, fixnum x, fixnum y) {
        modexp<modnum> me(x, x);
        fixnum zz;
        me(zz, x);
        z = zz;
    };
};

template< typename modnum >
struct my_multi_modexp {
    typedef typename modnum::fixnum fixnum;

    __device__ void operator()(fixnum &z, fixnum x, fixnum y) {
        multi_modexp<modnum> mme(x);
        fixnum zz;
        mme(zz, x, x);
        z = zz;
    };
};

typedef warp_fixnum<32, u64_fixnum> fixnum_256;
typedef fixnum_array<fixnum_256> fixnum_array_256;

template< int fn_bytes, typename word_fixnum, template <typename> class Func >
void bench(int nelts) {
    typedef warp_fixnum<fn_bytes, word_fixnum> fixnum;
    typedef fixnum_array<fixnum> fixnum_array;

    if (nelts == 0) {
        puts(" -*-  nelts == 0; skipping...  -*-");
        return;
    }

    uint8_t *input1 = new uint8_t[fn_bytes * nelts];
    for (int i = 0; i < fn_bytes * nelts; ++i)
        input1[i] = (i * 17 + 11) % 256;

    uint8_t *input2 = new uint8_t[fn_bytes * nelts];
    for (int i = 0; i < fn_bytes * nelts; ++i)
        input2[i] = ((i + 13) * 17 + 11) % 256;

    fixnum_array *res, *in_a, *in_b;
    in_a = fixnum_array::create(input1, fn_bytes * nelts, fn_bytes);
    in_b = fixnum_array::create(input2, fn_bytes * nelts, fn_bytes);
    res = fixnum_array::create(nelts);

    // warm up
    fixnum_array::template map<Func>(res, in_a, in_b);

    clock_t c = clock();
    fixnum_array::template map<Func>(res, in_a, in_b);
    c = clock() - c;

    double secinv = (double)CLOCKS_PER_SEC / c;
    double total_MiB = fixnum::BYTES * (double)nelts / (1 << 20);
    printf(" %4d   %3d    %6.1f   %7.3f  %12.1f\n",
           fixnum::BITS, fixnum::digit::BITS, total_MiB,
           1/secinv, nelts * 1e-3 * secinv);

    delete in_a;
    delete in_b;
    delete res;
    delete[] input1;
    delete[] input2;
}

template< template <typename> class Func >
void bench_func(const char *fn_name, int nelts) {
    printf("Function: %s, #elts: %de3\n", fn_name, (int)(nelts * 1e-3));
    printf("fixnum digit  total data   time       Kops/s\n");
    printf(" bits  bits     (MiB)    (seconds)\n");
    // bench<4, u32_fixnum, Func>(nelts);
    bench<8, u32_fixnum, Func>(nelts);
    bench<16, u32_fixnum, Func>(nelts);
    bench<32, u32_fixnum, Func>(nelts);
    bench<64, u32_fixnum, Func>(nelts);
    // bench<128, u32_fixnum, Func>(nelts);
    puts("");

    bench<8, u64_fixnum, Func>(nelts);
    bench<16, u64_fixnum, Func>(nelts);
    bench<32, u64_fixnum, Func>(nelts);
    bench<64, u64_fixnum, Func>(nelts);
    // bench<128, u64_fixnum, Func>(nelts);
    // bench<256, u64_fixnum, Func>(nelts);
    puts("");
}

// typedef std::array<uint256_t, 10> digit_cache_t;

// template<int DEC_LENGTH>
// constexpr std::array<std::array<uint256_t, 10>, DEC_LENGTH> get_digit_cache() {
//     digit_cache_t ret;


//     return ret;
// }

// template<int N>
// struct A {
//     constexpr A() : arr() {
//         for (auto i = 0; i < N; ++i) {
//             for (auto i = 0; i < 10; ++i) {
//                 arr[i] = i;
//             }
//         }
//     }
//     std::array<std::array<int, 10>, N> arr;
// };



constexpr uint256_t get_for_digit(int pos, int digit, int dec_length) {
    uint256_t ret = uint256_t(10).pow(pos) * digit;
    int reverse_pos = dec_length - pos - 1;
    if (pos != reverse_pos) {
        ret += uint256_t(10).pow(reverse_pos) * digit;
    }

    return ret;
}

constexpr uint256_t get_max(int pos, int base, int length) {
    return uint256_t(base).pow(length - pos - 1) - uint256_t(base).pow(pos + 1);
}


template<int BASE, int DEC_LENGTH>
struct MaxCache {
    constexpr MaxCache() : arr() {
        for (auto i = 0; i < DEC_LENGTH; ++i) {
            arr[i] = get_max(i, BASE, DEC_LENGTH);
        }
    }
    uint256_t arr[DEC_LENGTH];
};



struct state_t {
    uint256_t current_num;
    uint256_t bin_num;
    int level;
};


template<int DEC_LENGTH>
void find_palindrome_recursive(state_t initial) {
    state_t stack[DEC_LENGTH * 10];
    stack[0] = initial;
    int stack_index = 0;

    while (stack_index >= 0) {
        uint256_t current_num = stack[stack_index].current_num;
        uint256_t bin_num = stack[stack_index].bin_num;
        uint256_t level = stack[stack_index].level;
        stack_index -= 1;

        if (level + 1 * 2 >= DEC_LENGTH) {
        }
    }
}



int main(int, char **) {
    // long m = 1;
    // if (argc > 1)
    //     m = atol(argv[1]);
    // m = std::max(m, 100000L);

    // bench_func<add>("add", m);
    // puts("");

    // bench_func<add2>("add2", m);
    // puts("");

    // uint256_t bla;
    // state_t initial = {
    //     uint256_t(0), uint256_t(0), 0
    // };
    // find_palindrome_recursive<10>(initial);

    constexpr auto max_cache_2 = MaxCache<2, 5>();
    // constexpr uint256_t bla = get_max(5, 5, 5);

    uint256_t d = get_for_digit(3, 3, 12);
    std::cout << d.str() << std::endl;

    uint256_t m = get_max(1, 10, 5);
    std::cout << m.str() << std::endl;


    return 0;
}
