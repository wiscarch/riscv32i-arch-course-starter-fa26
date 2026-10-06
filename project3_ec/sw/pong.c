/*
 * pong -- one-dimensional pong across the ten red LEDs. Two players.
 *
 * The ball is a single lit LED travelling along LEDR. The last HIT_ZONE LEDs
 * at each end are that player's hit zone: press while the ball is coming
 * towards you inside it to send it back. Presses outside the zone are
 * ignored; let the ball run off the end and the other player scores. Each
 * successful return speeds the ball up, so rallies get progressively harder.
 *
 *   KEY0      left player  -- returns the ball at LEDR[0..1]
 *   KEY3      right player -- returns the ball at LEDR[8..9]
 *   LEDR      the ball
 *   HEX5      left player's score
 *   HEX0      right player's score
 *
 * First to 9 wins. The game then returns to attract mode -- the ball sweeps
 * back and forth with the final score still showing -- until someone presses
 * a button to start the next match.
 *
 * Why this one is worth building: it is small, it needs two people, and the
 * whole thing is visible from across a room -- which makes it a much better
 * demo-table program than anything that prints a number.
 *
 * ISA notes: no multiply, divide or modulo. Timing comes from the free-running
 * hardware cycle counter rather than a calibrated spin loop, because this ISA
 * has no CSRs and therefore no rdcycle. delay_ms() deliberately loops once per
 * millisecond instead of computing ms * MS_TICKS, since a runtime multiply
 * would become a __mulsi3 call. All state is local to main(), so there are no
 * initialised globals to go stale across a reset. Roughly 152 instructions.
 *
 * Build: riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -nostdlib
 *        -ffreestanding -fno-builtin
 */

/* ------------------------------------------------------------------ *
 * Memory-mapped I/O. Duplicated in each program for now; this block
 * moves to a shared io.h once the peripheral set settles.
 * ------------------------------------------------------------------ */
#define MMIO_BASE   0x80000000u

#define LEDR        (*(volatile unsigned int *)(MMIO_BASE + 0x00))  /* W, 10 bits           */
#define KEY_EDGE    (*(volatile unsigned int *)(MMIO_BASE + 0x0C))  /* R, sticky press latch*/
#define KEY_ACK     (*(volatile unsigned int *)(MMIO_BASE + 0x10))  /* W, write-1-to-clear  */
#define HEX_VAL     (*(volatile unsigned int *)(MMIO_BASE + 0x14))  /* W, 24b -> 6 nibbles  */
#define HEX_EN      (*(volatile unsigned int *)(MMIO_BASE + 0x20))  /* W, 6b digit enable   */
#define CYCLES      (*(volatile unsigned int *)(MMIO_BASE + 0x24))  /* R, free-running      */

#define KEY_LEFT    0x1u    /* KEY0 */
#define KEY_RIGHT   0x8u    /* KEY3 */

#define CPU_HZ      12500000u
#define MS_TICKS    (CPU_HZ / 1000u)   /* folded at compile time */

#define FIELD       10u     /* number of LEDs */
#define LAST        (FIELD - 1u)
#define WIN_SCORE   9u

#define HIT_ZONE    2u      /* LEDs at each end that accept a return */

#define SPEED_START 350u    /* ms per step at serve */
#define SPEED_STEP  20u     /* faster by this much per return */
#define SPEED_MIN   60u

/*
 * Busy-wait for a number of milliseconds, timed off the hardware cycle
 * counter. One outer iteration per millisecond keeps every arithmetic
 * operation an add or a compare -- no multiply.
 */
static void delay_ms(unsigned int ms)
{
    while (ms--) {
        unsigned int t0 = CYCLES;
        while ((CYCLES - t0) < MS_TICKS) {
            /* spin */
        }
    }
}

/*
 * Take and clear any latched button presses. The latch is sticky in hardware
 * so a press between polls is never lost, and clearing is an explicit write
 * rather than a read side effect.
 */
static unsigned int key_take(void)
{
    unsigned int e = KEY_EDGE & 0x0Fu;
    if (e)
        KEY_ACK = e;
    return e;
}

/* 16-bit Galois LFSR. Shifts and xor only -- no multiply, and small. */
static unsigned int lfsr_next(unsigned int s)
{
    unsigned int lsb = s & 1u;

    s >>= 1;
    if (lsb)
        s ^= 0xB400u;

    return s & 0xFFFFu;
}

static void show_score(unsigned int left, unsigned int right)
{
    HEX_VAL = (left << 20) | right;
}

/* Flash the whole bar n times -- used for a missed return and for a win. */
static void flash(unsigned int n, unsigned int ms)
{
    while (n--) {
        LEDR = 0x3FFu;
        delay_ms(ms);
        LEDR = 0u;
        delay_ms(ms);
    }
}

int main(void)
{
    unsigned int left = 0u, right = 0u;
    unsigned int pos, dir, speed;
    unsigned int seed = 1u;

    /* HEX5 and HEX0 only; the four middle digits stay dark. */
    HEX_EN = 0x21u;   /* 0b100001 */
    show_score(left, right);

    /* One match per iteration. */
    for (;;) {
        /*
         * Attract mode: sweep the ball back and forth until somebody presses
         * a button. The last match's score stays up meanwhile. The cycle
         * counter at the moment of the press seeds the LFSR, so the first
         * serve direction depends on human timing rather than being fixed.
         */
        key_take();   /* drop presses made during the win flash */
        pos = 0u;
        dir = 1u;
        for (;;) {
            LEDR = 1u << pos;
            delay_ms(70u);

            if (key_take()) {
                seed = CYCLES | 1u;   /* never let the LFSR seed be zero */
                break;
            }

            if (pos == LAST)
                dir = 0u;             /* 0 means "moving left" */
            else if (pos == 0u)
                dir = 1u;

            pos = dir ? (pos + 1u) : (pos - 1u);
        }

        left  = 0u;
        right = 0u;
        show_score(left, right);

        /* Serve from the middle, direction chosen by the LFSR. */
        seed  = lfsr_next(seed);
        pos   = FIELD / 2u;
        dir   = seed & 1u;
        speed = SPEED_START;

        for (;;) {
            unsigned int e;

            LEDR = 1u << pos;
            delay_ms(speed);

            e = key_take();

            /*
             * A press only counts while the ball is heading towards that
             * player and inside their hit zone, so a return can't be
             * re-triggered while the ball is still leaving.
             */
            if (!dir && pos < HIT_ZONE && (e & KEY_LEFT)) {
                dir = 1u;
                if (speed > SPEED_MIN + SPEED_STEP)
                    speed -= SPEED_STEP;
            } else if (dir && pos > LAST - HIT_ZONE && (e & KEY_RIGHT)) {
                dir = 0u;
                if (speed > SPEED_MIN + SPEED_STEP)
                    speed -= SPEED_STEP;
            } else if (!dir && pos == 0u) {
                /* Ran off the left end unreturned. */
                right++;
                goto point;
            } else if (dir && pos == LAST) {
                /* Ran off the right end unreturned. */
                left++;
                goto point;
            }

            pos = dir ? (pos + 1u) : (pos - 1u);
            continue;

        point:
            show_score(left, right);
            flash(3u, 90u);

            if (left >= WIN_SCORE || right >= WIN_SCORE) {
                flash(10u, 60u);
                break;            /* match over: back to attract mode */
            }

            /* Next serve: middle of the field, random direction, base speed. */
            seed  = lfsr_next(seed);
            pos   = FIELD / 2u;
            dir   = seed & 1u;
            speed = SPEED_START;
        }
    }

    return 0;   /* not reached */
}
