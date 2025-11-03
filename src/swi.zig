pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_labs = @import("std").zig.c_builtins.__builtin_labs;
pub const __builtin_llabs = @import("std").zig.c_builtins.__builtin_llabs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub const struct___va_list_tag_1 = extern struct {
    gp_offset: c_uint = @import("std").mem.zeroes(c_uint),
    fp_offset: c_uint = @import("std").mem.zeroes(c_uint),
    overflow_arg_area: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    reg_save_area: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};
pub const __builtin_va_list = [1]struct___va_list_tag_1;
pub const __gnuc_va_list = __builtin_va_list;
pub const va_list = __builtin_va_list;
pub const wchar_t = c_int;
pub const _Float32 = f32;
pub const _Float64 = f64;
pub const _Float32x = f64;
pub const _Float64x = c_longdouble;
pub const div_t = extern struct {
    quot: c_int = @import("std").mem.zeroes(c_int),
    rem: c_int = @import("std").mem.zeroes(c_int),
};
pub const ldiv_t = extern struct {
    quot: c_long = @import("std").mem.zeroes(c_long),
    rem: c_long = @import("std").mem.zeroes(c_long),
};
pub const lldiv_t = extern struct {
    quot: c_longlong = @import("std").mem.zeroes(c_longlong),
    rem: c_longlong = @import("std").mem.zeroes(c_longlong),
};
pub extern fn __ctype_get_mb_cur_max() usize;
pub extern fn atof(__nptr: [*c]const u8) f64;
pub extern fn atoi(__nptr: [*c]const u8) c_int;
pub extern fn atol(__nptr: [*c]const u8) c_long;
pub extern fn atoll(__nptr: [*c]const u8) c_longlong;
pub extern fn strtod(__nptr: [*c]const u8, __endptr: [*c][*c]u8) f64;
pub extern fn strtof(__nptr: [*c]const u8, __endptr: [*c][*c]u8) f32;
pub extern fn strtold(__nptr: [*c]const u8, __endptr: [*c][*c]u8) c_longdouble;
pub extern fn strtol(__nptr: [*c]const u8, __endptr: [*c][*c]u8, __base: c_int) c_long;
pub extern fn strtoul(__nptr: [*c]const u8, __endptr: [*c][*c]u8, __base: c_int) c_ulong;
pub extern fn strtoq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtouq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn strtoll(__nptr: [*c]const u8, __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtoull(__nptr: [*c]const u8, __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn l64a(__n: c_long) [*c]u8;
pub extern fn a64l(__s: [*c]const u8) c_long;
pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const u_char = __u_char;
pub const u_short = __u_short;
pub const u_int = __u_int;
pub const u_long = __u_long;
pub const quad_t = __quad_t;
pub const u_quad_t = __u_quad_t;
pub const fsid_t = __fsid_t;
pub const loff_t = __loff_t;
pub const ino_t = __ino_t;
pub const dev_t = __dev_t;
pub const gid_t = __gid_t;
pub const mode_t = __mode_t;
pub const nlink_t = __nlink_t;
pub const uid_t = __uid_t;
pub const off_t = __off_t;
pub const pid_t = __pid_t;
pub const id_t = __id_t;
pub const daddr_t = __daddr_t;
pub const caddr_t = __caddr_t;
pub const key_t = __key_t;
pub const clock_t = __clock_t;
pub const clockid_t = __clockid_t;
pub const time_t = __time_t;
pub const timer_t = __timer_t;
pub const ulong = c_ulong;
pub const ushort = c_ushort;
pub const uint = c_uint;
pub const u_int8_t = __uint8_t;
pub const u_int16_t = __uint16_t;
pub const u_int32_t = __uint32_t;
pub const u_int64_t = __uint64_t;
pub const register_t = c_long;
pub fn __bswap_16(arg___bsx: __uint16_t) callconv(.c) __uint16_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @as(__uint16_t, @bitCast(@as(c_short, @truncate(((@as(c_int, @bitCast(@as(c_uint, __bsx))) >> @intCast(8)) & @as(c_int, 255)) | ((@as(c_int, @bitCast(@as(c_uint, __bsx))) & @as(c_int, 255)) << @intCast(8))))));
}
pub fn __bswap_32(arg___bsx: __uint32_t) callconv(.c) __uint32_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return ((((__bsx & @as(c_uint, 4278190080)) >> @intCast(24)) | ((__bsx & @as(c_uint, 16711680)) >> @intCast(8))) | ((__bsx & @as(c_uint, 65280)) << @intCast(8))) | ((__bsx & @as(c_uint, 255)) << @intCast(24));
}
pub fn __bswap_64(arg___bsx: __uint64_t) callconv(.c) __uint64_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @as(__uint64_t, @bitCast(@as(c_ulong, @truncate(((((((((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 18374686479671623680)) >> @intCast(56)) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 71776119061217280)) >> @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 280375465082880)) >> @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 1095216660480)) >> @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 4278190080)) << @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 16711680)) << @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 65280)) << @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 255)) << @intCast(56))))));
}
pub fn __uint16_identity(arg___x: __uint16_t) callconv(.c) __uint16_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint32_identity(arg___x: __uint32_t) callconv(.c) __uint32_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint64_identity(arg___x: __uint64_t) callconv(.c) __uint64_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub const __sigset_t = extern struct {
    __val: [16]c_ulong = @import("std").mem.zeroes([16]c_ulong),
};
pub const sigset_t = __sigset_t;
pub const struct_timeval = extern struct {
    tv_sec: __time_t = @import("std").mem.zeroes(__time_t),
    tv_usec: __suseconds_t = @import("std").mem.zeroes(__suseconds_t),
};
pub const struct_timespec = extern struct {
    tv_sec: __time_t = @import("std").mem.zeroes(__time_t),
    tv_nsec: __syscall_slong_t = @import("std").mem.zeroes(__syscall_slong_t),
};
pub const suseconds_t = __suseconds_t;
pub const __fd_mask = c_long;
pub const fd_set = extern struct {
    __fds_bits: [16]__fd_mask = @import("std").mem.zeroes([16]__fd_mask),
};
pub const fd_mask = __fd_mask;
pub extern fn select(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]struct_timeval) c_int;
pub extern fn pselect(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]const struct_timespec, noalias __sigmask: [*c]const __sigset_t) c_int;
pub const blksize_t = __blksize_t;
pub const blkcnt_t = __blkcnt_t;
pub const fsblkcnt_t = __fsblkcnt_t;
pub const fsfilcnt_t = __fsfilcnt_t;
const struct_unnamed_2 = extern struct {
    __low: c_uint = @import("std").mem.zeroes(c_uint),
    __high: c_uint = @import("std").mem.zeroes(c_uint),
};
pub const __atomic_wide_counter = extern union {
    __value64: c_ulonglong,
    __value32: struct_unnamed_2,
};
pub const struct___pthread_internal_list = extern struct {
    __prev: [*c]struct___pthread_internal_list = @import("std").mem.zeroes([*c]struct___pthread_internal_list),
    __next: [*c]struct___pthread_internal_list = @import("std").mem.zeroes([*c]struct___pthread_internal_list),
};
pub const __pthread_list_t = struct___pthread_internal_list;
pub const struct___pthread_internal_slist = extern struct {
    __next: [*c]struct___pthread_internal_slist = @import("std").mem.zeroes([*c]struct___pthread_internal_slist),
};
pub const __pthread_slist_t = struct___pthread_internal_slist;
pub const struct___pthread_mutex_s = extern struct {
    __lock: c_int = @import("std").mem.zeroes(c_int),
    __count: c_uint = @import("std").mem.zeroes(c_uint),
    __owner: c_int = @import("std").mem.zeroes(c_int),
    __nusers: c_uint = @import("std").mem.zeroes(c_uint),
    __kind: c_int = @import("std").mem.zeroes(c_int),
    __spins: c_short = @import("std").mem.zeroes(c_short),
    __elision: c_short = @import("std").mem.zeroes(c_short),
    __list: __pthread_list_t = @import("std").mem.zeroes(__pthread_list_t),
};
pub const struct___pthread_rwlock_arch_t = extern struct {
    __readers: c_uint = @import("std").mem.zeroes(c_uint),
    __writers: c_uint = @import("std").mem.zeroes(c_uint),
    __wrphase_futex: c_uint = @import("std").mem.zeroes(c_uint),
    __writers_futex: c_uint = @import("std").mem.zeroes(c_uint),
    __pad3: c_uint = @import("std").mem.zeroes(c_uint),
    __pad4: c_uint = @import("std").mem.zeroes(c_uint),
    __cur_writer: c_int = @import("std").mem.zeroes(c_int),
    __shared: c_int = @import("std").mem.zeroes(c_int),
    __rwelision: i8 = @import("std").mem.zeroes(i8),
    __pad1: [7]u8 = @import("std").mem.zeroes([7]u8),
    __pad2: c_ulong = @import("std").mem.zeroes(c_ulong),
    __flags: c_uint = @import("std").mem.zeroes(c_uint),
};
pub const struct___pthread_cond_s = extern struct {
    __wseq: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g1_start: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g_refs: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g_size: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g1_orig_size: c_uint = @import("std").mem.zeroes(c_uint),
    __wrefs: c_uint = @import("std").mem.zeroes(c_uint),
    __g_signals: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
};
pub const __tss_t = c_uint;
pub const __thrd_t = c_ulong;
pub const __once_flag = extern struct {
    __data: c_int = @import("std").mem.zeroes(c_int),
};
pub const pthread_t = c_ulong;
pub const pthread_mutexattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_condattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_key_t = c_uint;
pub const pthread_once_t = c_int;
pub const union_pthread_attr_t = extern union {
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_attr_t = union_pthread_attr_t;
pub const pthread_mutex_t = extern union {
    __data: struct___pthread_mutex_s,
    __size: [40]u8,
    __align: c_long,
};
pub const pthread_cond_t = extern union {
    __data: struct___pthread_cond_s,
    __size: [48]u8,
    __align: c_longlong,
};
pub const pthread_rwlock_t = extern union {
    __data: struct___pthread_rwlock_arch_t,
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_rwlockattr_t = extern union {
    __size: [8]u8,
    __align: c_long,
};
pub const pthread_spinlock_t = c_int;
pub const pthread_barrier_t = extern union {
    __size: [32]u8,
    __align: c_long,
};
pub const pthread_barrierattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub extern fn random() c_long;
pub extern fn srandom(__seed: c_uint) void;
pub extern fn initstate(__seed: c_uint, __statebuf: [*c]u8, __statelen: usize) [*c]u8;
pub extern fn setstate(__statebuf: [*c]u8) [*c]u8;
pub const struct_random_data = extern struct {
    fptr: [*c]i32 = @import("std").mem.zeroes([*c]i32),
    rptr: [*c]i32 = @import("std").mem.zeroes([*c]i32),
    state: [*c]i32 = @import("std").mem.zeroes([*c]i32),
    rand_type: c_int = @import("std").mem.zeroes(c_int),
    rand_deg: c_int = @import("std").mem.zeroes(c_int),
    rand_sep: c_int = @import("std").mem.zeroes(c_int),
    end_ptr: [*c]i32 = @import("std").mem.zeroes([*c]i32),
};
pub extern fn random_r(noalias __buf: [*c]struct_random_data, noalias __result: [*c]i32) c_int;
pub extern fn srandom_r(__seed: c_uint, __buf: [*c]struct_random_data) c_int;
pub extern fn initstate_r(__seed: c_uint, noalias __statebuf: [*c]u8, __statelen: usize, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn setstate_r(noalias __statebuf: [*c]u8, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn rand() c_int;
pub extern fn srand(__seed: c_uint) void;
pub extern fn rand_r(__seed: [*c]c_uint) c_int;
pub extern fn drand48() f64;
pub extern fn erand48(__xsubi: [*c]c_ushort) f64;
pub extern fn lrand48() c_long;
pub extern fn nrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn mrand48() c_long;
pub extern fn jrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn srand48(__seedval: c_long) void;
pub extern fn seed48(__seed16v: [*c]c_ushort) [*c]c_ushort;
pub extern fn lcong48(__param: [*c]c_ushort) void;
pub const struct_drand48_data = extern struct {
    __x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __old_x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __c: c_ushort = @import("std").mem.zeroes(c_ushort),
    __init: c_ushort = @import("std").mem.zeroes(c_ushort),
    __a: c_ulonglong = @import("std").mem.zeroes(c_ulonglong),
};
pub extern fn drand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn erand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn lrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn nrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn mrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn jrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn srand48_r(__seedval: c_long, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn seed48_r(__seed16v: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn lcong48_r(__param: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn arc4random() __uint32_t;
pub extern fn arc4random_buf(__buf: ?*anyopaque, __size: usize) void;
pub extern fn arc4random_uniform(__upper_bound: __uint32_t) __uint32_t;
pub extern fn malloc(__size: c_ulong) ?*anyopaque;
pub extern fn calloc(__nmemb: c_ulong, __size: c_ulong) ?*anyopaque;
pub extern fn realloc(__ptr: ?*anyopaque, __size: c_ulong) ?*anyopaque;
pub extern fn free(__ptr: ?*anyopaque) void;
pub extern fn reallocarray(__ptr: ?*anyopaque, __nmemb: usize, __size: usize) ?*anyopaque;
pub extern fn alloca(__size: c_ulong) ?*anyopaque;
pub extern fn valloc(__size: usize) ?*anyopaque;
pub extern fn posix_memalign(__memptr: [*c]?*anyopaque, __alignment: usize, __size: usize) c_int;
pub extern fn aligned_alloc(__alignment: c_ulong, __size: c_ulong) ?*anyopaque;
pub extern fn abort() noreturn;
pub extern fn atexit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn at_quick_exit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn on_exit(__func: ?*const fn (c_int, ?*anyopaque) callconv(.c) void, __arg: ?*anyopaque) c_int;
pub extern fn exit(__status: c_int) noreturn;
pub extern fn quick_exit(__status: c_int) noreturn;
pub extern fn _Exit(__status: c_int) noreturn;
pub extern fn getenv(__name: [*c]const u8) [*c]u8;
pub extern fn putenv(__string: [*c]u8) c_int;
pub extern fn setenv(__name: [*c]const u8, __value: [*c]const u8, __replace: c_int) c_int;
pub extern fn unsetenv(__name: [*c]const u8) c_int;
pub extern fn clearenv() c_int;
pub extern fn mktemp(__template: [*c]u8) [*c]u8;
pub extern fn mkstemp(__template: [*c]u8) c_int;
pub extern fn mkstemps(__template: [*c]u8, __suffixlen: c_int) c_int;
pub extern fn mkdtemp(__template: [*c]u8) [*c]u8;
pub extern fn system(__command: [*c]const u8) c_int;
pub extern fn realpath(noalias __name: [*c]const u8, noalias __resolved: [*c]u8) [*c]u8;
pub const __compar_fn_t = ?*const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
pub extern fn bsearch(__key: ?*const anyopaque, __base: ?*const anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) ?*anyopaque;
pub extern fn qsort(__base: ?*anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) void;
pub extern fn abs(__x: c_int) c_int;
pub extern fn labs(__x: c_long) c_long;
pub extern fn llabs(__x: c_longlong) c_longlong;
pub extern fn div(__numer: c_int, __denom: c_int) div_t;
pub extern fn ldiv(__numer: c_long, __denom: c_long) ldiv_t;
pub extern fn lldiv(__numer: c_longlong, __denom: c_longlong) lldiv_t;
pub extern fn ecvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn fcvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn gcvt(__value: f64, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn qecvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qfcvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qgcvt(__value: c_longdouble, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn ecvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn fcvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qecvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qfcvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn mblen(__s: [*c]const u8, __n: usize) c_int;
pub extern fn mbtowc(noalias __pwc: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) c_int;
pub extern fn wctomb(__s: [*c]u8, __wchar: wchar_t) c_int;
pub extern fn mbstowcs(noalias __pwcs: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) usize;
pub extern fn wcstombs(noalias __s: [*c]u8, noalias __pwcs: [*c]const wchar_t, __n: usize) usize;
pub extern fn rpmatch(__response: [*c]const u8) c_int;
pub extern fn getsubopt(noalias __optionp: [*c][*c]u8, noalias __tokens: [*c]const [*c]u8, noalias __valuep: [*c][*c]u8) c_int;
pub extern fn getloadavg(__loadavg: [*c]f64, __nelem: c_int) c_int;
pub const ptrdiff_t = c_long;
pub const max_align_t = extern struct {
    __clang_max_align_nonce1: c_longlong align(8) = @import("std").mem.zeroes(c_longlong),
    __clang_max_align_nonce2: c_longdouble align(16) = @import("std").mem.zeroes(c_longdouble),
};
pub const int_least8_t = __int_least8_t;
pub const int_least16_t = __int_least16_t;
pub const int_least32_t = __int_least32_t;
pub const int_least64_t = __int_least64_t;
pub const uint_least8_t = __uint_least8_t;
pub const uint_least16_t = __uint_least16_t;
pub const uint_least32_t = __uint_least32_t;
pub const uint_least64_t = __uint_least64_t;
pub const int_fast8_t = i8;
pub const int_fast16_t = c_long;
pub const int_fast32_t = c_long;
pub const int_fast64_t = c_long;
pub const uint_fast8_t = u8;
pub const uint_fast16_t = c_ulong;
pub const uint_fast32_t = c_ulong;
pub const uint_fast64_t = c_ulong;
pub const intmax_t = __intmax_t;
pub const uintmax_t = __uintmax_t;
pub const __gwchar_t = c_int;
pub const imaxdiv_t = extern struct {
    quot: c_long = @import("std").mem.zeroes(c_long),
    rem: c_long = @import("std").mem.zeroes(c_long),
};
pub extern fn imaxabs(__n: intmax_t) intmax_t;
pub extern fn imaxdiv(__numer: intmax_t, __denom: intmax_t) imaxdiv_t;
pub extern fn strtoimax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) intmax_t;
pub extern fn strtoumax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) uintmax_t;
pub extern fn wcstoimax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) intmax_t;
pub extern fn wcstoumax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) uintmax_t;
pub const __PL_word = usize;
pub const atom_t = __PL_word;
pub const functor_t = __PL_word;
pub const __PL_code = usize;
pub const struct___PL_module = opaque {};
pub const module_t = ?*struct___PL_module;
pub const struct___PL_procedure = opaque {};
pub const predicate_t = ?*struct___PL_procedure;
pub const struct___PL_record = opaque {};
pub const record_t = ?*struct___PL_record;
pub const term_t = usize;
pub const struct___PL_queryRef = opaque {};
pub const qid_t = ?*struct___PL_queryRef;
pub const PL_fid_t = usize;
pub const struct___PL_foreign_context = opaque {};
pub const control_t = ?*struct___PL_foreign_context;
pub const struct___PL_PL_local_data = opaque {};
pub const PL_engine_t = ?*struct___PL_PL_local_data;
pub const PL_atomic_t = usize;
pub const foreign_t = usize;
pub const pl_wchar_t = wchar_t;
pub const pl_function_t = ?*const fn (...) callconv(.c) foreign_t;
pub const buf_mark_t = usize;
pub const struct_io_stream = opaque {};
pub const IOSTREAM = struct_io_stream;
const struct_unnamed_3 = extern struct {
    name: atom_t = @import("std").mem.zeroes(atom_t),
    arity: usize = @import("std").mem.zeroes(usize),
};
pub const term_value_t = extern union {
    i: i64,
    f: f64,
    s: [*c]u8,
    a: atom_t,
    t: struct_unnamed_3,
};
pub extern fn _PL_retry(isize) foreign_t;
pub extern fn _PL_retry_address(?*anyopaque) foreign_t;
pub extern fn _PL_yield_address(?*anyopaque) foreign_t;
pub extern fn PL_foreign_control(control_t) c_int;
pub extern fn PL_foreign_context(control_t) isize;
pub extern fn PL_foreign_context_address(control_t) ?*anyopaque;
pub extern fn PL_foreign_context_predicate(control_t) predicate_t;
pub const struct_PL_extension = extern struct {
    predicate_name: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    arity: c_short = @import("std").mem.zeroes(c_short),
    function: pl_function_t = @import("std").mem.zeroes(pl_function_t),
    flags: c_short = @import("std").mem.zeroes(c_short),
};
pub const PL_extension = struct_PL_extension;
pub const PL_extensions: [*c]PL_extension = @extern([*c]PL_extension, .{
    .name = "PL_extensions",
});
pub extern fn PL_register_extensions(e: [*c]const PL_extension) void;
pub extern fn PL_register_extensions_in_module(module: [*c]const u8, e: [*c]const PL_extension) void;
pub extern fn PL_register_foreign(name: [*c]const u8, arity: c_int, func: pl_function_t, flags: c_int, ...) c_int;
pub extern fn PL_register_foreign_in_module(module: [*c]const u8, name: [*c]const u8, arity: c_int, func: pl_function_t, flags: c_int, ...) c_int;
pub extern fn PL_load_extensions(e: [*c]const PL_extension) void;
pub extern fn PL_license(license: [*c]const u8, module: [*c]const u8) void;
pub extern fn PL_context() module_t;
pub extern fn PL_module_name(module: module_t) atom_t;
pub extern fn PL_new_module(name: atom_t) module_t;
pub extern fn PL_strip_module(in: term_t, m: [*c]module_t, out: term_t) c_int;
pub extern fn _PL_atoms() [*c]const atom_t;
pub extern fn PL_open_foreign_frame() PL_fid_t;
pub extern fn PL_rewind_foreign_frame(cid: PL_fid_t) void;
pub extern fn PL_close_foreign_frame(cid: PL_fid_t) void;
pub extern fn PL_discard_foreign_frame(cid: PL_fid_t) void;
pub extern fn PL_pred(f: functor_t, m: module_t) predicate_t;
pub extern fn PL_predicate(name: [*c]const u8, arity: c_int, module: [*c]const u8) predicate_t;
pub extern fn PL_predicate_info(pred: predicate_t, name: [*c]atom_t, arity: [*c]usize, module: [*c]module_t) c_int;
pub extern fn PL_open_query(m: module_t, flags: c_int, pred: predicate_t, t0: term_t) qid_t;
pub extern fn PL_next_solution(qid: qid_t) c_int;
pub extern fn PL_close_query(qid: qid_t) c_int;
pub extern fn PL_cut_query(qid: qid_t) c_int;
pub extern fn PL_current_query() qid_t;
pub extern fn PL_query_engine(qid: qid_t) PL_engine_t;
pub extern fn PL_can_yield() c_int;
pub extern fn PL_call(t: term_t, m: module_t) c_int;
pub extern fn PL_call_predicate(m: module_t, debug: c_int, pred: predicate_t, t0: term_t) c_int;
pub extern fn PL_exception(qid: qid_t) term_t;
pub extern fn PL_raise_exception(exception: term_t) c_int;
pub extern fn PL_throw(exception: term_t) c_int;
pub extern fn PL_clear_exception() void;
pub extern fn PL_yielded(qid: qid_t) term_t;
pub extern fn PL_assert(term: term_t, m: module_t, flags: c_int) c_int;
pub extern fn PL_new_term_refs(n: c_int) term_t;
pub extern fn PL_new_term_ref() term_t;
pub extern fn PL_copy_term_ref(from: term_t) term_t;
pub extern fn PL_reset_term_refs(r: term_t) void;
pub extern fn PL_new_atom(s: [*c]const u8) atom_t;
pub extern fn PL_new_atom_nchars(len: usize, s: [*c]const u8) atom_t;
pub extern fn PL_new_atom_wchars(len: usize, s: [*c]const pl_wchar_t) atom_t;
pub extern fn PL_new_atom_mbchars(rep: c_int, len: usize, s: [*c]const u8) atom_t;
pub extern fn PL_atom_chars(a: atom_t) [*c]const u8;
pub extern fn PL_atom_nchars(a: atom_t, len: [*c]usize) [*c]const u8;
pub extern fn PL_atom_mbchars(a: atom_t, len: [*c]usize, s: [*c][*c]u8, flags: c_uint) c_int;
pub extern fn PL_atom_wchars(a: atom_t, len: [*c]usize) [*c]const wchar_t;
pub extern fn PL_register_atom(a: atom_t) void;
pub extern fn PL_unregister_atom(a: atom_t) void;
pub extern fn PL_new_functor_sz(f: atom_t, a: usize) functor_t;
pub extern fn PL_new_functor(f: atom_t, a: c_int) functor_t;
pub extern fn PL_functor_name(f: functor_t) atom_t;
pub extern fn PL_functor_arity(f: functor_t) c_int;
pub extern fn PL_functor_arity_sz(f: functor_t) usize;
pub extern fn PL_get_atom(t: term_t, a: [*c]atom_t) c_int;
pub extern fn PL_get_bool(t: term_t, value: [*c]c_int) c_int;
pub extern fn PL_get_atom_chars(t: term_t, a: [*c][*c]u8) c_int;
pub extern fn PL_get_string(t: term_t, s: [*c][*c]u8, len: [*c]usize) c_int;
pub extern fn PL_get_chars(t: term_t, s: [*c][*c]u8, flags: c_uint) c_int;
pub extern fn PL_get_list_chars(l: term_t, s: [*c][*c]u8, flags: c_uint) c_int;
pub extern fn PL_get_atom_nchars(t: term_t, len: [*c]usize, a: [*c][*c]u8) c_int;
pub extern fn PL_get_list_nchars(l: term_t, len: [*c]usize, s: [*c][*c]u8, flags: c_uint) c_int;
pub extern fn PL_get_nchars(t: term_t, len: [*c]usize, s: [*c][*c]u8, flags: c_uint) c_int;
pub extern fn PL_get_integer(t: term_t, i: [*c]c_int) c_int;
pub extern fn PL_get_long(t: term_t, i: [*c]c_long) c_int;
pub extern fn PL_get_intptr(t: term_t, i: [*c]isize) c_int;
pub extern fn PL_get_pointer(t: term_t, ptr: [*c]?*anyopaque) c_int;
pub extern fn PL_get_float(t: term_t, f: [*c]f64) c_int;
pub extern fn PL_get_functor(t: term_t, f: [*c]functor_t) c_int;
pub extern fn PL_get_name_arity_sz(t: term_t, name: [*c]atom_t, arity: [*c]usize) c_int;
pub extern fn PL_get_compound_name_arity_sz(t: term_t, name: [*c]atom_t, arity: [*c]usize) c_int;
pub extern fn PL_get_name_arity(t: term_t, name: [*c]atom_t, arity: [*c]c_int) c_int;
pub extern fn PL_get_compound_name_arity(t: term_t, name: [*c]atom_t, arity: [*c]c_int) c_int;
pub extern fn PL_get_module(t: term_t, module: [*c]module_t) c_int;
pub extern fn PL_get_arg_sz(index: usize, t: term_t, a: term_t) c_int;
pub extern fn PL_get_arg(index: c_int, t: term_t, a: term_t) c_int;
pub extern fn PL_get_dict_key(key: atom_t, dict: term_t, value: term_t) c_int;
pub extern fn PL_get_list(l: term_t, h: term_t, t: term_t) c_int;
pub extern fn PL_get_head(l: term_t, h: term_t) c_int;
pub extern fn PL_get_tail(l: term_t, t: term_t) c_int;
pub extern fn PL_get_nil(l: term_t) c_int;
pub extern fn PL_get_term_value(t: term_t, v: [*c]term_value_t) c_int;
pub extern fn PL_quote(chr: c_int, data: [*c]const u8) [*c]u8;
pub extern fn PL_term_type(t: term_t) c_int;
pub extern fn PL_is_variable(t: term_t) c_int;
pub extern fn PL_is_ground(t: term_t) c_int;
pub extern fn PL_is_atom(t: term_t) c_int;
pub extern fn PL_is_integer(t: term_t) c_int;
pub extern fn PL_is_string(t: term_t) c_int;
pub extern fn PL_is_float(t: term_t) c_int;
pub extern fn PL_is_rational(t: term_t) c_int;
pub extern fn PL_is_compound(t: term_t) c_int;
pub extern fn PL_is_callable(t: term_t) c_int;
pub extern fn PL_is_functor(t: term_t, f: functor_t) c_int;
pub extern fn PL_is_list(t: term_t) c_int;
pub extern fn PL_is_dict(t: term_t) c_int;
pub extern fn PL_is_pair(t: term_t) c_int;
pub extern fn PL_is_atomic(t: term_t) c_int;
pub extern fn PL_is_number(t: term_t) c_int;
pub extern fn PL_is_acyclic(t: term_t) c_int;
pub extern fn PL_put_variable(t: term_t) c_int;
pub extern fn PL_put_atom(t: term_t, a: atom_t) c_int;
pub extern fn PL_put_bool(t: term_t, val: c_int) c_int;
pub extern fn PL_put_atom_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_put_string_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_put_chars(t: term_t, flags: c_int, len: usize, chars: [*c]const u8) c_int;
pub extern fn PL_put_list_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_put_list_codes(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_put_atom_nchars(t: term_t, l: usize, chars: [*c]const u8) c_int;
pub extern fn PL_put_string_nchars(t: term_t, len: usize, chars: [*c]const u8) c_int;
pub extern fn PL_put_list_nchars(t: term_t, l: usize, chars: [*c]const u8) c_int;
pub extern fn PL_put_list_ncodes(t: term_t, l: usize, chars: [*c]const u8) c_int;
pub extern fn PL_put_integer(t: term_t, i: c_long) c_int;
pub extern fn PL_put_pointer(t: term_t, ptr: ?*anyopaque) c_int;
pub extern fn PL_put_float(t: term_t, f: f64) c_int;
pub extern fn PL_put_functor(t: term_t, functor: functor_t) c_int;
pub extern fn PL_put_list(l: term_t) c_int;
pub extern fn PL_put_nil(l: term_t) c_int;
pub extern fn PL_put_term(t1: term_t, t2: term_t) c_int;
pub extern fn PL_put_dict(t: term_t, tag: atom_t, len: usize, keys: [*c]const atom_t, values: term_t) c_int;
pub extern fn PL_cons_functor(h: term_t, f: functor_t, ...) c_int;
pub extern fn PL_cons_functor_v(h: term_t, fd: functor_t, a0: term_t) c_int;
pub extern fn PL_cons_list(l: term_t, h: term_t, t: term_t) c_int;
pub extern fn PL_unify(t1: term_t, t2: term_t) c_int;
pub extern fn PL_unify_atom(t: term_t, a: atom_t) c_int;
pub extern fn PL_unify_atom_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_unify_list_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_unify_list_codes(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_unify_string_chars(t: term_t, chars: [*c]const u8) c_int;
pub extern fn PL_unify_atom_nchars(t: term_t, l: usize, s: [*c]const u8) c_int;
pub extern fn PL_unify_list_ncodes(t: term_t, l: usize, s: [*c]const u8) c_int;
pub extern fn PL_unify_list_nchars(t: term_t, l: usize, s: [*c]const u8) c_int;
pub extern fn PL_unify_string_nchars(t: term_t, len: usize, chars: [*c]const u8) c_int;
pub extern fn PL_unify_bool(t: term_t, n: c_int) c_int;
pub extern fn PL_unify_integer(t: term_t, n: isize) c_int;
pub extern fn PL_unify_float(t: term_t, f: f64) c_int;
pub extern fn PL_unify_pointer(t: term_t, ptr: ?*anyopaque) c_int;
pub extern fn PL_unify_functor(t: term_t, f: functor_t) c_int;
pub extern fn PL_unify_compound(t: term_t, f: functor_t) c_int;
pub extern fn PL_unify_list(l: term_t, h: term_t, t: term_t) c_int;
pub extern fn PL_unify_nil(l: term_t) c_int;
pub extern fn PL_unify_arg_sz(index: usize, t: term_t, a: term_t) c_int;
pub extern fn PL_unify_arg(index: c_int, t: term_t, a: term_t) c_int;
pub extern fn PL_unify_term(t: term_t, ...) c_int;
pub extern fn PL_unify_chars(t: term_t, flags: c_int, len: usize, s: [*c]const u8) c_int;
pub extern fn PL_skip_list(list: term_t, tail: term_t, len: [*c]usize) c_int;
pub extern fn PL_unify_wchars(t: term_t, @"type": c_int, len: usize, s: [*c]const pl_wchar_t) c_int;
pub extern fn PL_unify_wchars_diff(t: term_t, tail: term_t, @"type": c_int, len: usize, s: [*c]const pl_wchar_t) c_int;
pub extern fn PL_get_wchars(l: term_t, length: [*c]usize, s: [*c][*c]pl_wchar_t, flags: c_uint) c_int;
pub extern fn PL_utf8_strlen(s: [*c]const u8, len: usize) usize;
pub extern fn PL_get_int64(t: term_t, i: [*c]i64) c_int;
pub extern fn PL_get_uint64(t: term_t, i: [*c]u64) c_int;
pub extern fn PL_unify_int64(t: term_t, value: i64) c_int;
pub extern fn PL_unify_uint64(t: term_t, value: u64) c_int;
pub extern fn PL_put_int64(t: term_t, i: i64) c_int;
pub extern fn PL_put_uint64(t: term_t, i: u64) c_int;
pub extern fn PL_is_attvar(t: term_t) c_int;
pub extern fn PL_get_attr(v: term_t, a: term_t) c_int;
pub extern fn PL_get_atom_ex(t: term_t, a: [*c]atom_t) c_int;
pub extern fn PL_get_integer_ex(t: term_t, i: [*c]c_int) c_int;
pub extern fn PL_get_long_ex(t: term_t, i: [*c]c_long) c_int;
pub extern fn PL_get_int64_ex(t: term_t, i: [*c]i64) c_int;
pub extern fn PL_get_uint64_ex(t: term_t, i: [*c]u64) c_int;
pub extern fn PL_get_intptr_ex(t: term_t, i: [*c]isize) c_int;
pub extern fn PL_get_size_ex(t: term_t, i: [*c]usize) c_int;
pub extern fn PL_get_bool_ex(t: term_t, i: [*c]c_int) c_int;
pub extern fn PL_get_float_ex(t: term_t, f: [*c]f64) c_int;
pub extern fn PL_get_char_ex(t: term_t, p: [*c]c_int, eof: c_int) c_int;
pub extern fn PL_unify_bool_ex(t: term_t, val: c_int) c_int;
pub extern fn PL_get_pointer_ex(t: term_t, addrp: [*c]?*anyopaque) c_int;
pub extern fn PL_unify_list_ex(l: term_t, h: term_t, t: term_t) c_int;
pub extern fn PL_unify_nil_ex(l: term_t) c_int;
pub extern fn PL_get_list_ex(l: term_t, h: term_t, t: term_t) c_int;
pub extern fn PL_get_nil_ex(l: term_t) c_int;
pub extern fn PL_instantiation_error(culprit: term_t) c_int;
pub extern fn PL_uninstantiation_error(culprit: term_t) c_int;
pub extern fn PL_representation_error(resource: [*c]const u8) c_int;
pub extern fn PL_type_error(expected: [*c]const u8, culprit: term_t) c_int;
pub extern fn PL_domain_error(expected: [*c]const u8, culprit: term_t) c_int;
pub extern fn PL_existence_error(@"type": [*c]const u8, culprit: term_t) c_int;
pub extern fn PL_permission_error(operation: [*c]const u8, @"type": [*c]const u8, culprit: term_t) c_int;
pub extern fn PL_resource_error(resource: [*c]const u8) c_int;
pub extern fn PL_syntax_error(msg: [*c]const u8, in: ?*IOSTREAM) c_int;
pub const struct_PL_blob_t = extern struct {
    magic: usize = @import("std").mem.zeroes(usize),
    flags: usize = @import("std").mem.zeroes(usize),
    name: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    release: ?*const fn (atom_t) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (atom_t) callconv(.c) c_int),
    compare: ?*const fn (atom_t, atom_t) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (atom_t, atom_t) callconv(.c) c_int),
    write: ?*const fn (?*IOSTREAM, atom_t, c_int) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (?*IOSTREAM, atom_t, c_int) callconv(.c) c_int),
    acquire: ?*const fn (atom_t) callconv(.c) void = @import("std").mem.zeroes(?*const fn (atom_t) callconv(.c) void),
    save: ?*const fn (atom_t, ?*IOSTREAM) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (atom_t, ?*IOSTREAM) callconv(.c) c_int),
    load: ?*const fn (?*IOSTREAM) callconv(.c) atom_t = @import("std").mem.zeroes(?*const fn (?*IOSTREAM) callconv(.c) atom_t),
    padding: usize = @import("std").mem.zeroes(usize),
    reserved: [9]?*anyopaque = @import("std").mem.zeroes([9]?*anyopaque),
    registered: c_int = @import("std").mem.zeroes(c_int),
    rank: c_int = @import("std").mem.zeroes(c_int),
    next: [*c]struct_PL_blob_t = @import("std").mem.zeroes([*c]struct_PL_blob_t),
    atom_name: atom_t = @import("std").mem.zeroes(atom_t),
};
pub const PL_blob_t = struct_PL_blob_t;
pub extern fn PL_is_blob(t: term_t, @"type": [*c][*c]PL_blob_t) c_int;
pub extern fn PL_unify_blob(t: term_t, blob: ?*anyopaque, len: usize, @"type": [*c]PL_blob_t) c_int;
pub extern fn PL_put_blob(t: term_t, blob: ?*anyopaque, len: usize, @"type": [*c]PL_blob_t) c_int;
pub extern fn PL_get_blob(t: term_t, blob: [*c]?*anyopaque, len: [*c]usize, @"type": [*c][*c]PL_blob_t) c_int;
pub extern fn PL_blob_data(a: atom_t, len: [*c]usize, @"type": [*c][*c]struct_PL_blob_t) ?*anyopaque;
pub extern fn PL_register_blob_type(@"type": [*c]PL_blob_t) void;
pub extern fn PL_find_blob_type(name: [*c]const u8) [*c]PL_blob_t;
pub extern fn PL_unregister_blob_type(@"type": [*c]PL_blob_t) c_int;
pub extern fn PL_get_file_name(n: term_t, name: [*c][*c]u8, flags: c_int) c_int;
pub extern fn PL_get_file_nameW(n: term_t, name: [*c][*c]wchar_t, flags: c_int) c_int;
pub extern fn PL_changed_cwd() void;
pub extern fn PL_cwd(buf: [*c]u8, buflen: usize) [*c]u8;
pub extern fn PL_cvt_i_bool(p: term_t, c: [*c]c_int) c_int;
pub extern fn PL_cvt_i_char(p: term_t, c: [*c]u8) c_int;
pub extern fn PL_cvt_i_schar(p: term_t, c: [*c]i8) c_int;
pub extern fn PL_cvt_i_uchar(p: term_t, c: [*c]u8) c_int;
pub extern fn PL_cvt_i_short(p: term_t, s: [*c]c_short) c_int;
pub extern fn PL_cvt_i_ushort(p: term_t, s: [*c]c_ushort) c_int;
pub extern fn PL_cvt_i_int(p: term_t, c: [*c]c_int) c_int;
pub extern fn PL_cvt_i_uint(p: term_t, c: [*c]c_uint) c_int;
pub extern fn PL_cvt_i_long(p: term_t, c: [*c]c_long) c_int;
pub extern fn PL_cvt_i_ulong(p: term_t, c: [*c]c_ulong) c_int;
pub extern fn PL_cvt_i_llong(p: term_t, c: [*c]c_longlong) c_int;
pub extern fn PL_cvt_i_ullong(p: term_t, c: [*c]c_ulonglong) c_int;
pub extern fn PL_cvt_i_int32(p: term_t, c: [*c]i32) c_int;
pub extern fn PL_cvt_i_uint32(p: term_t, c: [*c]u32) c_int;
pub extern fn PL_cvt_i_int64(p: term_t, c: [*c]i64) c_int;
pub extern fn PL_cvt_i_uint64(p: term_t, c: [*c]u64) c_int;
pub extern fn PL_cvt_i_size_t(p: term_t, c: [*c]usize) c_int;
pub extern fn PL_cvt_i_float(p: term_t, c: [*c]f64) c_int;
pub extern fn PL_cvt_i_single(p: term_t, c: [*c]f32) c_int;
pub extern fn PL_cvt_i_string(p: term_t, c: [*c][*c]u8) c_int;
pub extern fn PL_cvt_i_codes(p: term_t, c: [*c][*c]u8) c_int;
pub extern fn PL_cvt_i_atom(p: term_t, c: [*c]atom_t) c_int;
pub extern fn PL_cvt_i_address(p: term_t, c: ?*anyopaque) c_int;
pub extern fn PL_cvt_o_int64(c: i64, p: term_t) c_int;
pub extern fn PL_cvt_o_float(c: f64, p: term_t) c_int;
pub extern fn PL_cvt_o_single(c: f32, p: term_t) c_int;
pub extern fn PL_cvt_o_string(c: [*c]const u8, p: term_t) c_int;
pub extern fn PL_cvt_o_codes(c: [*c]const u8, p: term_t) c_int;
pub extern fn PL_cvt_o_atom(c: atom_t, p: term_t) c_int;
pub extern fn PL_cvt_o_address(address: ?*anyopaque, p: term_t) c_int;
pub extern fn PL_new_nil_ref() term_t;
pub extern fn PL_cvt_encoding() c_int;
pub extern fn PL_cvt_set_encoding(enc: c_int) c_int;
pub extern fn SP_set_state(state: c_int) void;
pub extern fn SP_get_state() c_int;
pub extern fn PL_compare(t1: term_t, t2: term_t) c_int;
pub extern fn PL_same_compound(t1: term_t, t2: term_t) c_int;
pub extern fn PL_warning(fmt: [*c]const u8, ...) c_int;
pub extern fn PL_fatal_error(fmt: [*c]const u8, ...) void;
pub extern fn PL_record(term: term_t) record_t;
pub extern fn PL_recorded(record: record_t, term: term_t) c_int;
pub extern fn PL_erase(record: record_t) void;
pub extern fn PL_duplicate_record(r: record_t) record_t;
pub extern fn PL_record_external(t: term_t, size: [*c]usize) [*c]u8;
pub extern fn PL_recorded_external(rec: [*c]const u8, term: term_t) c_int;
pub extern fn PL_erase_external(rec: [*c]u8) c_int;
pub extern fn PL_set_prolog_flag(name: [*c]const u8, @"type": c_int, ...) c_int;
pub extern fn _PL_get_atomic(t: term_t) PL_atomic_t;
pub extern fn _PL_put_atomic(t: term_t, a: PL_atomic_t) void;
pub extern fn _PL_unify_atomic(t: term_t, a: PL_atomic_t) c_int;
pub extern fn _PL_get_arg_sz(index: usize, t: term_t, a: term_t) c_int;
pub extern fn _PL_get_arg(index: c_int, t: term_t, a: term_t) c_int;
pub extern fn PL_mark_string_buffers(mark: [*c]buf_mark_t) void;
pub extern fn PL_release_string_buffers_from_mark(mark: buf_mark_t) void;
pub extern fn PL_unify_stream(t: term_t, s: ?*IOSTREAM) c_int;
pub extern fn PL_get_stream_handle(t: term_t, s: [*c]?*IOSTREAM) c_int;
pub extern fn PL_get_stream(t: term_t, s: [*c]?*IOSTREAM, flags: c_int) c_int;
pub extern fn PL_get_stream_from_blob(a: atom_t, s: [*c]?*IOSTREAM, flags: c_int) c_int;
pub extern fn PL_acquire_stream(s: ?*IOSTREAM) ?*IOSTREAM;
pub extern fn PL_release_stream(s: ?*IOSTREAM) c_int;
pub extern fn PL_release_stream_noerror(s: ?*IOSTREAM) c_int;
pub extern fn PL_open_resource(m: module_t, name: [*c]const u8, rc_class: [*c]const u8, mode: [*c]const u8) ?*IOSTREAM;
pub extern fn _PL_streams() [*c]?*IOSTREAM;
pub extern fn PL_write_term(s: ?*IOSTREAM, term: term_t, precedence: c_int, flags: c_int) c_int;
pub extern fn PL_ttymode(s: ?*IOSTREAM) c_int;
pub extern fn PL_put_term_from_chars(t: term_t, flags: c_int, len: usize, s: [*c]const u8) c_int;
pub extern fn PL_chars_to_term(chars: [*c]const u8, term: term_t) c_int;
pub extern fn PL_wchars_to_term(chars: [*c]const pl_wchar_t, term: term_t) c_int;
pub extern fn PL_initialise(argc: c_int, argv: [*c][*c]u8) c_int;
pub extern fn PL_winitialise(argc: c_int, argv: [*c][*c]wchar_t) c_int;
pub extern fn PL_is_initialised(argc: [*c]c_int, argv: [*c][*c][*c]u8) c_int;
pub extern fn PL_set_resource_db_mem(data: [*c]const u8, size: usize) c_int;
pub extern fn PL_toplevel() c_int;
pub extern fn PL_cleanup(status: c_int) c_int;
pub extern fn PL_cleanup_fork() void;
pub extern fn PL_halt(status: c_int) c_int;
pub extern fn PL_dlopen(file: [*c]const u8, flags: c_int) ?*anyopaque;
pub extern fn PL_dlerror() [*c]const u8;
pub extern fn PL_dlsym(handle: ?*anyopaque, symbol: [*c]u8) ?*anyopaque;
pub extern fn PL_dlclose(handle: ?*anyopaque) c_int;
pub extern fn PL_dispatch(fd: c_int, wait: c_int) c_int;
pub extern fn PL_add_to_protocol(buf: [*c]const u8, count: usize) void;
pub extern fn PL_prompt_string(fd: c_int) [*c]u8;
pub extern fn PL_write_prompt(dowrite: c_int) void;
pub extern fn PL_prompt_next(fd: c_int) void;
pub extern fn PL_atom_generator(prefix: [*c]const u8, state: c_int) [*c]u8;
pub extern fn PL_atom_generator_w(pref: [*c]const pl_wchar_t, buffer: [*c]pl_wchar_t, buflen: usize, state: c_int) [*c]pl_wchar_t;
pub extern fn PL_malloc(size: usize) ?*anyopaque;
pub extern fn PL_malloc_atomic(size: usize) ?*anyopaque;
pub extern fn PL_malloc_uncollectable(size: usize) ?*anyopaque;
pub extern fn PL_malloc_atomic_uncollectable(size: usize) ?*anyopaque;
pub extern fn PL_realloc(mem: ?*anyopaque, size: usize) ?*anyopaque;
pub extern fn PL_malloc_unmanaged(size: usize) ?*anyopaque;
pub extern fn PL_malloc_atomic_unmanaged(size: usize) ?*anyopaque;
pub extern fn PL_free(mem: ?*anyopaque) void;
pub extern fn PL_linger(mem: ?*anyopaque) c_int;
pub const PL_dispatch_hook_t = ?*const fn (c_int) callconv(.c) c_int;
pub const PL_abort_hook_t = ?*const fn () callconv(.c) void;
pub const PL_initialise_hook_t = ?*const fn (c_int, [*c][*c]u8) callconv(.c) void;
pub const PL_agc_hook_t = ?*const fn (atom_t) callconv(.c) c_int;
pub extern fn PL_dispatch_hook(PL_dispatch_hook_t) PL_dispatch_hook_t;
pub extern fn PL_abort_hook(PL_abort_hook_t) void;
pub extern fn PL_initialise_hook(PL_initialise_hook_t) void;
pub extern fn PL_abort_unhook(PL_abort_hook_t) c_int;
pub extern fn PL_agc_hook(PL_agc_hook_t) PL_agc_hook_t;
pub const _OPT_END: c_int = -1;
pub const OPT_BOOL: c_int = 0;
pub const OPT_INT: c_int = 1;
pub const OPT_INT64: c_int = 2;
pub const OPT_UINT64: c_int = 3;
pub const OPT_SIZE: c_int = 4;
pub const OPT_DOUBLE: c_int = 5;
pub const OPT_STRING: c_int = 6;
pub const OPT_ATOM: c_int = 7;
pub const OPT_TERM: c_int = 8;
pub const OPT_LOCALE: c_int = 9;
pub const _PL_opt_enum_t = c_int;
pub const PL_option_t = extern struct {
    name: atom_t = @import("std").mem.zeroes(atom_t),
    type: _PL_opt_enum_t = @import("std").mem.zeroes(_PL_opt_enum_t),
    string: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
};
pub extern fn PL_scan_options(options: term_t, flags: c_int, opttype: [*c]const u8, specs: [*c]PL_option_t, ...) c_int;
pub const struct_pl_sigaction = extern struct {
    sa_cfunction: ?*const fn (c_int) callconv(.c) void = @import("std").mem.zeroes(?*const fn (c_int) callconv(.c) void),
    sa_predicate: predicate_t = @import("std").mem.zeroes(predicate_t),
    sa_flags: c_int = @import("std").mem.zeroes(c_int),
    reserved: [2]?*anyopaque = @import("std").mem.zeroes([2]?*anyopaque),
};
pub const pl_sigaction_t = struct_pl_sigaction;
pub extern fn PL_signal(sig: c_int, func: ?*const fn (c_int) callconv(.c) void) ?*const fn (c_int) callconv(.c) void;
pub extern fn PL_sigaction(sig: c_int, act: [*c]pl_sigaction_t, old: [*c]pl_sigaction_t) c_int;
pub extern fn PL_interrupt(sig: c_int) void;
pub extern fn PL_raise(sig: c_int) c_int;
pub extern fn PL_handle_signals() c_int;
pub extern fn PL_get_signum_ex(sig: term_t, n: [*c]c_int) c_int;
pub extern fn PL_action(c_int, ...) c_int;
pub extern fn PL_on_halt(?*const fn (c_int, ?*anyopaque) callconv(.c) c_int, ?*anyopaque) void;
pub extern fn PL_exit_hook(?*const fn (c_int, ?*anyopaque) callconv(.c) c_int, ?*anyopaque) void;
pub extern fn PL_backtrace(depth: c_int, flags: c_int) void;
pub extern fn PL_backtrace_string(depth: c_int, flags: c_int) [*c]u8;
pub extern fn PL_check_data(data: term_t) c_int;
pub extern fn PL_check_stacks() c_int;
pub extern fn PL_current_prolog_flag(name: atom_t, @"type": c_int, ptr: ?*anyopaque) c_int;
pub extern fn PL_version_info(which: c_int) c_uint;
pub extern fn PL_query(c_int) isize;
pub const PL_THREAD_CANCEL_FAILED: c_int = 0;
pub const PL_THREAD_CANCEL_JOINED: c_int = 1;
pub const PL_THREAD_CANCEL_MUST_JOIN: c_int = 2;
pub const rc_cancel = c_uint;
pub const PL_thread_attr_t = extern struct {
    stack_limit: usize = @import("std").mem.zeroes(usize),
    table_space: usize = @import("std").mem.zeroes(usize),
    alias: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    cancel: ?*const fn (c_int) callconv(.c) rc_cancel = @import("std").mem.zeroes(?*const fn (c_int) callconv(.c) rc_cancel),
    flags: isize = @import("std").mem.zeroes(isize),
    max_queue_size: usize = @import("std").mem.zeroes(usize),
    reserved: [3]?*anyopaque = @import("std").mem.zeroes([3]?*anyopaque),
};
pub extern fn PL_thread_self() c_int;
pub extern fn PL_unify_thread_id(t: term_t, i: c_int) c_int;
pub extern fn PL_get_thread_id_ex(t: term_t, idp: [*c]c_int) c_int;
pub extern fn PL_get_thread_alias(tid: c_int, alias: [*c]atom_t) c_int;
pub extern fn PL_thread_attach_engine(attr: [*c]PL_thread_attr_t) c_int;
pub extern fn PL_thread_destroy_engine() c_int;
pub extern fn PL_thread_at_exit(function: ?*const fn (?*anyopaque) callconv(.c) void, closure: ?*anyopaque, global: c_int) c_int;
pub extern fn PL_thread_raise(tid: c_int, sig: c_int) c_int;
pub extern fn PL_create_engine(attributes: [*c]PL_thread_attr_t) PL_engine_t;
pub extern fn PL_set_engine(engine: PL_engine_t, old: [*c]PL_engine_t) c_int;
pub extern fn PL_destroy_engine(engine: PL_engine_t) c_int;
pub const struct___PL_table = opaque {};
pub const hash_table_t = ?*struct___PL_table;
pub const struct___PL_table_enum = opaque {};
pub const hash_table_enum_t = ?*struct___PL_table_enum;
pub extern fn PL_new_hash_table(size: c_int, free_symbol: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) void) hash_table_t;
pub extern fn PL_free_hash_table(table: hash_table_t) c_int;
pub extern fn PL_lookup_hash_table(table: hash_table_t, key: ?*anyopaque) ?*anyopaque;
pub extern fn PL_add_hash_table(table: hash_table_t, key: ?*anyopaque, value: ?*anyopaque, flags: c_int) ?*anyopaque;
pub extern fn PL_del_hash_table(table: hash_table_t, key: ?*anyopaque) ?*anyopaque;
pub extern fn PL_clear_hash_table(table: hash_table_t) c_int;
pub extern fn PL_new_hash_table_enum(table: hash_table_t) hash_table_enum_t;
pub extern fn PL_free_hash_table_enum(e: hash_table_enum_t) void;
pub extern fn PL_advance_hash_table_enum(e: hash_table_enum_t, key: [*c]?*anyopaque, value: [*c]?*anyopaque) c_int;
pub const PL_prof_type_t = extern struct {
    unify: ?*const fn (term_t, ?*anyopaque) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (term_t, ?*anyopaque) callconv(.c) c_int),
    get: ?*const fn (term_t, [*c]?*anyopaque) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (term_t, [*c]?*anyopaque) callconv(.c) c_int),
    activate: ?*const fn (c_int) callconv(.c) void = @import("std").mem.zeroes(?*const fn (c_int) callconv(.c) void),
    release: ?*const fn (?*anyopaque) callconv(.c) void = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) void),
    dummy: [4]?*anyopaque = @import("std").mem.zeroes([4]?*anyopaque),
    magic: isize = @import("std").mem.zeroes(isize),
};
pub extern fn PL_register_profile_type(@"type": [*c]PL_prof_type_t) c_int;
pub extern fn PL_prof_call(handle: ?*anyopaque, @"type": [*c]PL_prof_type_t) ?*anyopaque;
pub extern fn PL_prof_exit(node: ?*anyopaque) void;
pub extern var plugin_is_GPL_compatible: c_int;
pub extern fn emacs_module_init(?*anyopaque) c_int;
pub extern fn PL_prolog_debug(topic: [*c]const u8) c_int;
pub extern fn PL_prolog_nodebug(topic: [*c]const u8) c_int;
const union_unnamed_4 = extern union {
    i: usize,
    a: atom_t,
};
pub const xpceref_t = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    value: union_unnamed_4 = @import("std").mem.zeroes(union_unnamed_4),
};
pub extern fn _PL_get_xpce_reference(t: term_t, ref: [*c]xpceref_t) c_int;
pub extern fn _PL_unify_xpce_reference(t: term_t, ref: [*c]xpceref_t) c_int;
pub extern fn _PL_put_xpce_reference_i(t: term_t, r: usize) c_int;
pub extern fn _PL_put_xpce_reference_a(t: term_t, name: atom_t) c_int;
pub const struct___PL_queryFrame_5 = opaque {};
pub const struct___PL_localFrame_6 = opaque {};
pub const struct_pl_context_t = extern struct {
    ld: PL_engine_t = @import("std").mem.zeroes(PL_engine_t),
    qf: ?*struct___PL_queryFrame_5 = @import("std").mem.zeroes(?*struct___PL_queryFrame_5),
    fr: ?*struct___PL_localFrame_6 = @import("std").mem.zeroes(?*struct___PL_localFrame_6),
    pc: [*c]__PL_code = @import("std").mem.zeroes([*c]__PL_code),
    reserved: [10]?*anyopaque = @import("std").mem.zeroes([10]?*anyopaque),
};
pub const pl_context_t = struct_pl_context_t;
pub extern fn PL_get_context(c: [*c]struct_pl_context_t, thead_id: c_int) c_int;
pub extern fn PL_step_context(c: [*c]struct_pl_context_t) c_int;
pub extern fn PL_describe_context(c: [*c]struct_pl_context_t, buf: [*c]u8, len: usize) c_int;
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 20);
pub const __clang_minor__ = @as(c_int, 1);
pub const __clang_patchlevel__ = @as(c_int, 2);
pub const __clang_version__ = "20.1.2 (https://github.com/ziglang/zig-bootstrap c6bc9398c72c7a63fe9420a9055dcfd1845bc266)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __MEMORY_SCOPE_SYSTEM = @as(c_int, 0);
pub const __MEMORY_SCOPE_DEVICE = @as(c_int, 1);
pub const __MEMORY_SCOPE_WRKGRP = @as(c_int, 2);
pub const __MEMORY_SCOPE_WVFRNT = @as(c_int, 3);
pub const __MEMORY_SCOPE_SINGLE = @as(c_int, 4);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __FPCLASS_SNAN = @as(c_int, 0x0001);
pub const __FPCLASS_QNAN = @as(c_int, 0x0002);
pub const __FPCLASS_NEGINF = @as(c_int, 0x0004);
pub const __FPCLASS_NEGNORMAL = @as(c_int, 0x0008);
pub const __FPCLASS_NEGSUBNORMAL = @as(c_int, 0x0010);
pub const __FPCLASS_NEGZERO = @as(c_int, 0x0020);
pub const __FPCLASS_POSZERO = @as(c_int, 0x0040);
pub const __FPCLASS_POSSUBNORMAL = @as(c_int, 0x0080);
pub const __FPCLASS_POSNORMAL = @as(c_int, 0x0100);
pub const __FPCLASS_POSINF = @as(c_int, 0x0200);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 20.1.2 (https://github.com/ziglang/zig-bootstrap c6bc9398c72c7a63fe9420a9055dcfd1845bc266)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-32";
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 1);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LLONG_WIDTH__ = @as(c_int, 64);
pub const __BITINT_MAXWIDTH__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 8388608, .decimal);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_FMTd__ = "ld";
pub const __INTMAX_FMTi__ = "li";
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):95:9
pub const __INTMAX_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_FMTo__ = "lo";
pub const __UINTMAX_FMTu__ = "lu";
pub const __UINTMAX_FMTx__ = "lx";
pub const __UINTMAX_FMTX__ = "lX";
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):102:9
pub const __UINTMAX_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const __PTRDIFF_TYPE__ = c_long;
pub const __PTRDIFF_FMTd__ = "ld";
pub const __PTRDIFF_FMTi__ = "li";
pub const __INTPTR_TYPE__ = c_long;
pub const __INTPTR_FMTd__ = "ld";
pub const __INTPTR_FMTi__ = "li";
pub const __SIZE_TYPE__ = c_ulong;
pub const __SIZE_FMTo__ = "lo";
pub const __SIZE_FMTu__ = "lu";
pub const __SIZE_FMTx__ = "lx";
pub const __SIZE_FMTX__ = "lX";
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __UINTPTR_FMTo__ = "lo";
pub const __UINTPTR_FMTu__ = "lu";
pub const __UINTPTR_FMTx__ = "lx";
pub const __UINTPTR_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_NORM_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT16_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_NORM_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_NORM_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_NORM_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub inline fn __INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub inline fn __INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub inline fn __INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):207:9
pub const __INT64_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub inline fn __UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub inline fn __UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`");
// (no file):232:9
pub const __UINT32_C = @import("std").zig.c_translation.Macros.U_SUFFIX;
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):241:9
pub const __UINT64_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const __UINT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_LEAST64_FMTd__ = "ld";
pub const __INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_LEAST64_FMTo__ = "lo";
pub const __UINT_LEAST64_FMTu__ = "lu";
pub const __UINT_LEAST64_FMTx__ = "lx";
pub const __UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_FAST64_FMTd__ = "ld";
pub const __INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_FAST64_FMTo__ = "lo";
pub const __UINT_FAST64_FMTu__ = "lu";
pub const __UINT_FAST64_FMTx__ = "lx";
pub const __UINT_FAST64_FMTX__ = "lX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __GCC_DESTRUCTIVE_SIZE = @as(c_int, 64);
pub const __GCC_CONSTRUCTIVE_SIZE = @as(c_int, 64);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __NO_INLINE__ = @as(c_int, 1);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __SSP_STRONG__ = @as(c_int, 2);
pub const __ELF__ = @as(c_int, 1);
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):376:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):377:9
pub const __corei7 = @as(c_int, 1);
pub const __corei7__ = @as(c_int, 1);
pub const __tune_corei7__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __VAES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __VPCLMULQDQ__ = @as(c_int, 1);
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __GFNI__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLWB__ = @as(c_int, 1);
pub const __SHSTK__ = @as(c_int, 1);
pub const __KL__ = @as(c_int, 1);
pub const __WIDEKL__ = @as(c_int, 1);
pub const __RDPID__ = @as(c_int, 1);
pub const __WAITPKG__ = @as(c_int, 1);
pub const __MOVDIRI__ = @as(c_int, 1);
pub const __MOVDIR64B__ = @as(c_int, 1);
pub const __PCONFIG__ = @as(c_int, 1);
pub const __PTWRITE__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __HRESET__ = @as(c_int, 1);
pub const __AVXVNNI__ = @as(c_int, 1);
pub const __SERIALIZE__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const __gnu_linux__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 39);
pub const __GCC_HAVE_DWARF2_CFI_ASM = @as(c_int, 1);
pub const _SWI_PROLOG_H = "";
pub const __SWI_PROLOG__ = "";
pub const __need___va_list = "";
pub const __need_va_list = "";
pub const __need_va_arg = "";
pub const __need___va_copy = "";
pub const __need_va_copy = "";
pub const __STDARG_H = "";
pub const __GNUC_VA_LIST = "";
pub const _VA_LIST = "";
pub const va_start = @compileError("unable to translate macro: undefined identifier `__builtin_va_start`");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stdarg_va_arg.h:17:9
pub const va_end = @compileError("unable to translate macro: undefined identifier `__builtin_va_end`");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stdarg_va_arg.h:19:9
pub const va_arg = @compileError("unable to translate C expr: unexpected token 'an identifier'");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stdarg_va_arg.h:20:9
pub const __va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stdarg___va_copy.h:11:9
pub const va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stdarg_va_copy.h:11:9
pub const __GLIBC_INTERNAL_STARTING_HEADER_IMPLEMENTATION = "";
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`");
// /usr/include/features.h:188:9
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC2X = @as(c_int, 0);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_POSIX_IMPLICITLY = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 200809);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const __GLIBC_USE_C2X_STRTOL = @as(c_int, 0);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__has_builtin(name)) {
    _ = &name;
    return __has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:55:10
pub const __LEAF = "";
pub const __LEAF_ATTR = "";
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:82:11
pub const __COLD = @compileError("unable to translate macro: undefined identifier `__cold__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:102:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:131:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token '#'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:132:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin_object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin_object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub const __warnattr = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:216:10
pub const __errordecl = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:217:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:225:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:256:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:263:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:265:11
pub const __ASMNAME = @compileError("unable to translate C expr: unexpected token ','");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:268:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __REDIRECT_FORTIFY = __REDIRECT;
pub const __REDIRECT_FORTIFY_NTH = __REDIRECT_NTH;
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:298:10
pub const __attribute_alloc_size__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:309:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:315:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:325:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:332:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:338:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:347:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:348:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:356:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:366:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:379:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:389:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:401:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:414:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:423:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:441:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:450:10
pub const __extern_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:468:11
pub const __extern_always_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:469:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:512:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub const __attribute_copy__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:561:10
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub const __LDBL_REDIR2_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:638:10
pub const __LDBL_REDIR_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:639:10
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:653:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:654:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub const __fortified_attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:699:11
pub const __attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:700:11
pub const __attr_access_none = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:701:11
pub const __attr_dealloc = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:711:10
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:718:10
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const __GLIBC_USE_LIB_EXT2 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT_C2X = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT_C2X = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_TYPES_EXT = @as(c_int, 0);
pub const __need_size_t = "";
pub const __need_wchar_t = "";
pub const __need_NULL = "";
pub const _SIZE_T = "";
pub const _WCHAR_T = "";
pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
pub const _STDLIB_H = @as(c_int, 1);
pub const WNOHANG = @as(c_int, 1);
pub const WUNTRACED = @as(c_int, 2);
pub const WSTOPPED = @as(c_int, 2);
pub const WEXITED = @as(c_int, 4);
pub const WCONTINUED = @as(c_int, 8);
pub const WNOWAIT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const __WNOTHREAD = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x20000000, .hex);
pub const __WALL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x40000000, .hex);
pub const __WCLONE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x80000000, .hex);
pub inline fn __WEXITSTATUS(status: anytype) @TypeOf((status & @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8)) {
    _ = &status;
    return (status & @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8);
}
pub inline fn __WTERMSIG(status: anytype) @TypeOf(status & @as(c_int, 0x7f)) {
    _ = &status;
    return status & @as(c_int, 0x7f);
}
pub inline fn __WSTOPSIG(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn __WIFEXITED(status: anytype) @TypeOf(__WTERMSIG(status) == @as(c_int, 0)) {
    _ = &status;
    return __WTERMSIG(status) == @as(c_int, 0);
}
pub inline fn __WIFSIGNALED(status: anytype) @TypeOf((@import("std").zig.c_translation.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0)) {
    _ = &status;
    return (@import("std").zig.c_translation.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0);
}
pub inline fn __WIFSTOPPED(status: anytype) @TypeOf((status & @as(c_int, 0xff)) == @as(c_int, 0x7f)) {
    _ = &status;
    return (status & @as(c_int, 0xff)) == @as(c_int, 0x7f);
}
pub inline fn __WIFCONTINUED(status: anytype) @TypeOf(status == __W_CONTINUED) {
    _ = &status;
    return status == __W_CONTINUED;
}
pub inline fn __WCOREDUMP(status: anytype) @TypeOf(status & __WCOREFLAG) {
    _ = &status;
    return status & __WCOREFLAG;
}
pub inline fn __W_EXITCODE(ret: anytype, sig: anytype) @TypeOf((ret << @as(c_int, 8)) | sig) {
    _ = &ret;
    _ = &sig;
    return (ret << @as(c_int, 8)) | sig;
}
pub inline fn __W_STOPCODE(sig: anytype) @TypeOf((sig << @as(c_int, 8)) | @as(c_int, 0x7f)) {
    _ = &sig;
    return (sig << @as(c_int, 8)) | @as(c_int, 0x7f);
}
pub const __W_CONTINUED = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffff, .hex);
pub const __WCOREFLAG = @as(c_int, 0x80);
pub inline fn WEXITSTATUS(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn WTERMSIG(status: anytype) @TypeOf(__WTERMSIG(status)) {
    _ = &status;
    return __WTERMSIG(status);
}
pub inline fn WSTOPSIG(status: anytype) @TypeOf(__WSTOPSIG(status)) {
    _ = &status;
    return __WSTOPSIG(status);
}
pub inline fn WIFEXITED(status: anytype) @TypeOf(__WIFEXITED(status)) {
    _ = &status;
    return __WIFEXITED(status);
}
pub inline fn WIFSIGNALED(status: anytype) @TypeOf(__WIFSIGNALED(status)) {
    _ = &status;
    return __WIFSIGNALED(status);
}
pub inline fn WIFSTOPPED(status: anytype) @TypeOf(__WIFSTOPPED(status)) {
    _ = &status;
    return __WIFSTOPPED(status);
}
pub inline fn WIFCONTINUED(status: anytype) @TypeOf(__WIFCONTINUED(status)) {
    _ = &status;
    return __WIFCONTINUED(status);
}
pub const _BITS_FLOATN_H = "";
pub const __HAVE_FLOAT128 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128 = @as(c_int, 0);
pub const __HAVE_FLOAT64X = @as(c_int, 1);
pub const __HAVE_FLOAT64X_LONG_DOUBLE = @as(c_int, 1);
pub const _BITS_FLOATN_COMMON_H = "";
pub const __HAVE_FLOAT16 = @as(c_int, 0);
pub const __HAVE_FLOAT32 = @as(c_int, 1);
pub const __HAVE_FLOAT64 = @as(c_int, 1);
pub const __HAVE_FLOAT32X = @as(c_int, 1);
pub const __HAVE_FLOAT128X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT16 = __HAVE_FLOAT16;
pub const __HAVE_DISTINCT_FLOAT32 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT32X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128X = __HAVE_FLOAT128X;
pub const __HAVE_FLOAT128_UNLIKE_LDBL = (__HAVE_DISTINCT_FLOAT128 != 0) and (__LDBL_MANT_DIG__ != @as(c_int, 113));
pub const __HAVE_FLOATN_NOT_TYPEDEF = @as(c_int, 0);
pub const __f32 = @import("std").zig.c_translation.Macros.F_SUFFIX;
pub inline fn __f64(x: anytype) @TypeOf(x) {
    _ = &x;
    return x;
}
pub inline fn __f32x(x: anytype) @TypeOf(x) {
    _ = &x;
    return x;
}
pub const __f64x = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const __CFLOAT32 = @compileError("unable to translate: TODO _Complex");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:149:12
pub const __CFLOAT64 = @compileError("unable to translate: TODO _Complex");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:160:13
pub const __CFLOAT32X = @compileError("unable to translate: TODO _Complex");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:169:12
pub const __CFLOAT64X = @compileError("unable to translate: TODO _Complex");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:178:13
pub inline fn __builtin_huge_valf32() @TypeOf(__builtin_huge_valf()) {
    return __builtin_huge_valf();
}
pub inline fn __builtin_inff32() @TypeOf(__builtin_inff()) {
    return __builtin_inff();
}
pub inline fn __builtin_nanf32(x: anytype) @TypeOf(__builtin_nanf(x)) {
    _ = &x;
    return __builtin_nanf(x);
}
pub const __builtin_nansf32 = @compileError("unable to translate macro: undefined identifier `__builtin_nansf`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:221:12
pub const __builtin_huge_valf64 = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:255:13
pub const __builtin_inff64 = @compileError("unable to translate macro: undefined identifier `__builtin_inf`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:256:13
pub const __builtin_nanf64 = @compileError("unable to translate macro: undefined identifier `__builtin_nan`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:257:13
pub const __builtin_nansf64 = @compileError("unable to translate macro: undefined identifier `__builtin_nans`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:258:13
pub const __builtin_huge_valf32x = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:272:12
pub const __builtin_inff32x = @compileError("unable to translate macro: undefined identifier `__builtin_inf`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:273:12
pub const __builtin_nanf32x = @compileError("unable to translate macro: undefined identifier `__builtin_nan`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:274:12
pub const __builtin_nansf32x = @compileError("unable to translate macro: undefined identifier `__builtin_nans`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:275:12
pub const __builtin_huge_valf64x = @compileError("unable to translate macro: undefined identifier `__builtin_huge_vall`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:289:13
pub const __builtin_inff64x = @compileError("unable to translate macro: undefined identifier `__builtin_infl`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:290:13
pub const __builtin_nanf64x = @compileError("unable to translate macro: undefined identifier `__builtin_nanl`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:291:13
pub const __builtin_nansf64x = @compileError("unable to translate macro: undefined identifier `__builtin_nansl`");
// /usr/include/x86_64-linux-gnu/bits/floatn-common.h:292:13
pub const __ldiv_t_defined = @as(c_int, 1);
pub const __lldiv_t_defined = @as(c_int, 1);
pub const RAND_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const EXIT_FAILURE = @as(c_int, 1);
pub const EXIT_SUCCESS = @as(c_int, 0);
pub const MB_CUR_MAX = __ctype_get_mb_cur_max();
pub const _SYS_TYPES_H = @as(c_int, 1);
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const __STD_TYPE = @compileError("unable to translate C expr: unexpected token 'typedef'");
// /usr/include/x86_64-linux-gnu/bits/types.h:137:10
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`");
// /usr/include/x86_64-linux-gnu/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const __u_char_defined = "";
pub const __ino_t_defined = "";
pub const __dev_t_defined = "";
pub const __gid_t_defined = "";
pub const __mode_t_defined = "";
pub const __nlink_t_defined = "";
pub const __uid_t_defined = "";
pub const __off_t_defined = "";
pub const __pid_t_defined = "";
pub const __id_t_defined = "";
pub const __ssize_t_defined = "";
pub const __daddr_t_defined = "";
pub const __key_t_defined = "";
pub const __clock_t_defined = @as(c_int, 1);
pub const __clockid_t_defined = @as(c_int, 1);
pub const __time_t_defined = @as(c_int, 1);
pub const __timer_t_defined = @as(c_int, 1);
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const __BIT_TYPES_DEFINED__ = @as(c_int, 1);
pub const _ENDIAN_H = @as(c_int, 1);
pub const _BITS_ENDIAN_H = @as(c_int, 1);
pub const __LITTLE_ENDIAN = @as(c_int, 1234);
pub const __BIG_ENDIAN = @as(c_int, 4321);
pub const __PDP_ENDIAN = @as(c_int, 3412);
pub const _BITS_ENDIANNESS_H = @as(c_int, 1);
pub const __BYTE_ORDER = __LITTLE_ENDIAN;
pub const __FLOAT_WORD_ORDER = __BYTE_ORDER;
pub inline fn __LONG_LONG_PAIR(HI: anytype, LO: anytype) @TypeOf(HI) {
    _ = &HI;
    _ = &LO;
    return blk: {
        _ = &LO;
        break :blk HI;
    };
}
pub const LITTLE_ENDIAN = __LITTLE_ENDIAN;
pub const BIG_ENDIAN = __BIG_ENDIAN;
pub const PDP_ENDIAN = __PDP_ENDIAN;
pub const BYTE_ORDER = __BYTE_ORDER;
pub const _BITS_BYTESWAP_H = @as(c_int, 1);
pub inline fn __bswap_constant_16(x: anytype) __uint16_t {
    _ = &x;
    return @import("std").zig.c_translation.cast(__uint16_t, ((x >> @as(c_int, 8)) & @as(c_int, 0xff)) | ((x & @as(c_int, 0xff)) << @as(c_int, 8)));
}
pub inline fn __bswap_constant_32(x: anytype) @TypeOf(((((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24))) {
    _ = &x;
    return ((((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24));
}
pub inline fn __bswap_constant_64(x: anytype) @TypeOf(((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56))) {
    _ = &x;
    return ((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56));
}
pub const _BITS_UINTN_IDENTITY_H = @as(c_int, 1);
pub inline fn htobe16(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn htole16(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn be16toh(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn le16toh(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn htobe32(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn htole32(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn be32toh(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn le32toh(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn htobe64(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn htole64(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub inline fn be64toh(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn le64toh(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub const _SYS_SELECT_H = @as(c_int, 1);
pub const __FD_ZERO = @compileError("unable to translate macro: undefined identifier `__i`");
// /usr/include/x86_64-linux-gnu/bits/select.h:25:9
pub const __FD_SET = @compileError("unable to translate C expr: expected ')' instead got '|='");
// /usr/include/x86_64-linux-gnu/bits/select.h:32:9
pub const __FD_CLR = @compileError("unable to translate C expr: expected ')' instead got '&='");
// /usr/include/x86_64-linux-gnu/bits/select.h:34:9
pub inline fn __FD_ISSET(d: anytype, s: anytype) @TypeOf((__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0)) {
    _ = &d;
    _ = &s;
    return (__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0);
}
pub const __sigset_t_defined = @as(c_int, 1);
pub const ____sigset_t_defined = "";
pub const _SIGSET_NWORDS = @import("std").zig.c_translation.MacroArithmetic.div(@as(c_int, 1024), @as(c_int, 8) * @import("std").zig.c_translation.sizeof(c_ulong));
pub const __timeval_defined = @as(c_int, 1);
pub const _STRUCT_TIMESPEC = @as(c_int, 1);
pub const __suseconds_t_defined = "";
pub const __NFDBITS = @as(c_int, 8) * @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.sizeof(__fd_mask));
pub inline fn __FD_ELT(d: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.div(d, __NFDBITS)) {
    _ = &d;
    return @import("std").zig.c_translation.MacroArithmetic.div(d, __NFDBITS);
}
pub inline fn __FD_MASK(d: anytype) __fd_mask {
    _ = &d;
    return @import("std").zig.c_translation.cast(__fd_mask, @as(c_ulong, 1) << @import("std").zig.c_translation.MacroArithmetic.rem(d, __NFDBITS));
}
pub inline fn __FDS_BITS(set: anytype) @TypeOf(set.*.__fds_bits) {
    _ = &set;
    return set.*.__fds_bits;
}
pub const FD_SETSIZE = __FD_SETSIZE;
pub const NFDBITS = __NFDBITS;
pub inline fn FD_SET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_SET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_SET(fd, fdsetp);
}
pub inline fn FD_CLR(fd: anytype, fdsetp: anytype) @TypeOf(__FD_CLR(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_CLR(fd, fdsetp);
}
pub inline fn FD_ISSET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_ISSET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_ISSET(fd, fdsetp);
}
pub inline fn FD_ZERO(fdsetp: anytype) @TypeOf(__FD_ZERO(fdsetp)) {
    _ = &fdsetp;
    return __FD_ZERO(fdsetp);
}
pub const __blksize_t_defined = "";
pub const __blkcnt_t_defined = "";
pub const __fsblkcnt_t_defined = "";
pub const __fsfilcnt_t_defined = "";
pub const _BITS_PTHREADTYPES_COMMON_H = @as(c_int, 1);
pub const _THREAD_SHARED_TYPES_H = @as(c_int, 1);
pub const _BITS_PTHREADTYPES_ARCH_H = @as(c_int, 1);
pub const __SIZEOF_PTHREAD_MUTEX_T = @as(c_int, 40);
pub const __SIZEOF_PTHREAD_ATTR_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_RWLOCK_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_BARRIER_T = @as(c_int, 32);
pub const __SIZEOF_PTHREAD_MUTEXATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_COND_T = @as(c_int, 48);
pub const __SIZEOF_PTHREAD_CONDATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_RWLOCKATTR_T = @as(c_int, 8);
pub const __SIZEOF_PTHREAD_BARRIERATTR_T = @as(c_int, 4);
pub const __LOCK_ALIGNMENT = "";
pub const __ONCE_ALIGNMENT = "";
pub const _BITS_ATOMIC_WIDE_COUNTER_H = "";
pub const _THREAD_MUTEX_INTERNAL_H = @as(c_int, 1);
pub const __PTHREAD_MUTEX_HAVE_PREV = @as(c_int, 1);
pub const __PTHREAD_MUTEX_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/struct_mutex.h:56:10
pub const _RWLOCK_INTERNAL_H = "";
pub const __PTHREAD_RWLOCK_ELISION_EXTRA = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/struct_rwlock.h:40:11
pub inline fn __PTHREAD_RWLOCK_INITIALIZER(__flags: anytype) @TypeOf(__flags) {
    _ = &__flags;
    return blk: {
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = &__PTHREAD_RWLOCK_ELISION_EXTRA;
        _ = @as(c_int, 0);
        break :blk __flags;
    };
}
pub const __ONCE_FLAG_INIT = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/thread-shared-types.h:113:9
pub const __have_pthread_attr_t = @as(c_int, 1);
pub const _ALLOCA_H = @as(c_int, 1);
pub const __COMPAR_FN_T = "";
pub const __need_ptrdiff_t = "";
pub const __need_max_align_t = "";
pub const __need_offsetof = "";
pub const __STDDEF_H = "";
pub const _PTRDIFF_T = "";
pub const __CLANG_MAX_ALIGN_T_DEFINED = "";
pub const offsetof = @compileError("unable to translate C expr: unexpected token 'an identifier'");
// /usr/local/zig-x86_64-linux-0.15.1/lib/include/__stddef_offsetof.h:16:9
pub const __CLANG_INTTYPES_H = "";
pub const _INTTYPES_H = @as(c_int, 1);
pub const __CLANG_STDINT_H = "";
pub const _STDINT_H = @as(c_int, 1);
pub const _BITS_WCHAR_H = @as(c_int, 1);
pub const __WCHAR_MAX = __WCHAR_MAX__;
pub const __WCHAR_MIN = -__WCHAR_MAX - @as(c_int, 1);
pub const _BITS_STDINT_UINTN_H = @as(c_int, 1);
pub const _BITS_STDINT_LEAST_H = @as(c_int, 1);
pub const __intptr_t_defined = "";
pub const INT8_MIN = -@as(c_int, 128);
pub const INT16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT8_MAX = @as(c_int, 127);
pub const INT16_MAX = @as(c_int, 32767);
pub const INT32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT8_MAX = @as(c_int, 255);
pub const UINT16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_LEAST8_MIN = -@as(c_int, 128);
pub const INT_LEAST16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT_LEAST32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT_LEAST64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_LEAST8_MAX = @as(c_int, 127);
pub const INT_LEAST16_MAX = @as(c_int, 32767);
pub const INT_LEAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT_LEAST64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_LEAST8_MAX = @as(c_int, 255);
pub const UINT_LEAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_FAST8_MIN = -@as(c_int, 128);
pub const INT_FAST16_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_FAST8_MAX = @as(c_int, 127);
pub const INT_FAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_FAST8_MAX = @as(c_int, 255);
pub const UINT_FAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INTPTR_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INTPTR_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const UINTPTR_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const INTMAX_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INTMAX_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINTMAX_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const PTRDIFF_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const PTRDIFF_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const SIG_ATOMIC_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const SIG_ATOMIC_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SIZE_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const WCHAR_MIN = __WCHAR_MIN;
pub const WCHAR_MAX = __WCHAR_MAX;
pub const WINT_MIN = @as(c_uint, 0);
pub const WINT_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub inline fn INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const INT64_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub inline fn UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const UINT32_C = @import("std").zig.c_translation.Macros.U_SUFFIX;
pub const UINT64_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const INTMAX_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const UINTMAX_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const ____gwchar_t_defined = @as(c_int, 1);
pub const __PRI64_PREFIX = "l";
pub const __PRIPTR_PREFIX = "l";
pub const PRId8 = "d";
pub const PRId16 = "d";
pub const PRId32 = "d";
pub const PRId64 = __PRI64_PREFIX ++ "d";
pub const PRIdLEAST8 = "d";
pub const PRIdLEAST16 = "d";
pub const PRIdLEAST32 = "d";
pub const PRIdLEAST64 = __PRI64_PREFIX ++ "d";
pub const PRIdFAST8 = "d";
pub const PRIdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST64 = __PRI64_PREFIX ++ "d";
pub const PRIi8 = "i";
pub const PRIi16 = "i";
pub const PRIi32 = "i";
pub const PRIi64 = __PRI64_PREFIX ++ "i";
pub const PRIiLEAST8 = "i";
pub const PRIiLEAST16 = "i";
pub const PRIiLEAST32 = "i";
pub const PRIiLEAST64 = __PRI64_PREFIX ++ "i";
pub const PRIiFAST8 = "i";
pub const PRIiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST64 = __PRI64_PREFIX ++ "i";
pub const PRIo8 = "o";
pub const PRIo16 = "o";
pub const PRIo32 = "o";
pub const PRIo64 = __PRI64_PREFIX ++ "o";
pub const PRIoLEAST8 = "o";
pub const PRIoLEAST16 = "o";
pub const PRIoLEAST32 = "o";
pub const PRIoLEAST64 = __PRI64_PREFIX ++ "o";
pub const PRIoFAST8 = "o";
pub const PRIoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST64 = __PRI64_PREFIX ++ "o";
pub const PRIu8 = "u";
pub const PRIu16 = "u";
pub const PRIu32 = "u";
pub const PRIu64 = __PRI64_PREFIX ++ "u";
pub const PRIuLEAST8 = "u";
pub const PRIuLEAST16 = "u";
pub const PRIuLEAST32 = "u";
pub const PRIuLEAST64 = __PRI64_PREFIX ++ "u";
pub const PRIuFAST8 = "u";
pub const PRIuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST64 = __PRI64_PREFIX ++ "u";
pub const PRIx8 = "x";
pub const PRIx16 = "x";
pub const PRIx32 = "x";
pub const PRIx64 = __PRI64_PREFIX ++ "x";
pub const PRIxLEAST8 = "x";
pub const PRIxLEAST16 = "x";
pub const PRIxLEAST32 = "x";
pub const PRIxLEAST64 = __PRI64_PREFIX ++ "x";
pub const PRIxFAST8 = "x";
pub const PRIxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST64 = __PRI64_PREFIX ++ "x";
pub const PRIX8 = "X";
pub const PRIX16 = "X";
pub const PRIX32 = "X";
pub const PRIX64 = __PRI64_PREFIX ++ "X";
pub const PRIXLEAST8 = "X";
pub const PRIXLEAST16 = "X";
pub const PRIXLEAST32 = "X";
pub const PRIXLEAST64 = __PRI64_PREFIX ++ "X";
pub const PRIXFAST8 = "X";
pub const PRIXFAST16 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST32 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST64 = __PRI64_PREFIX ++ "X";
pub const PRIdMAX = __PRI64_PREFIX ++ "d";
pub const PRIiMAX = __PRI64_PREFIX ++ "i";
pub const PRIoMAX = __PRI64_PREFIX ++ "o";
pub const PRIuMAX = __PRI64_PREFIX ++ "u";
pub const PRIxMAX = __PRI64_PREFIX ++ "x";
pub const PRIXMAX = __PRI64_PREFIX ++ "X";
pub const PRIdPTR = __PRIPTR_PREFIX ++ "d";
pub const PRIiPTR = __PRIPTR_PREFIX ++ "i";
pub const PRIoPTR = __PRIPTR_PREFIX ++ "o";
pub const PRIuPTR = __PRIPTR_PREFIX ++ "u";
pub const PRIxPTR = __PRIPTR_PREFIX ++ "x";
pub const PRIXPTR = __PRIPTR_PREFIX ++ "X";
pub const SCNd8 = "hhd";
pub const SCNd16 = "hd";
pub const SCNd32 = "d";
pub const SCNd64 = __PRI64_PREFIX ++ "d";
pub const SCNdLEAST8 = "hhd";
pub const SCNdLEAST16 = "hd";
pub const SCNdLEAST32 = "d";
pub const SCNdLEAST64 = __PRI64_PREFIX ++ "d";
pub const SCNdFAST8 = "hhd";
pub const SCNdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST64 = __PRI64_PREFIX ++ "d";
pub const SCNi8 = "hhi";
pub const SCNi16 = "hi";
pub const SCNi32 = "i";
pub const SCNi64 = __PRI64_PREFIX ++ "i";
pub const SCNiLEAST8 = "hhi";
pub const SCNiLEAST16 = "hi";
pub const SCNiLEAST32 = "i";
pub const SCNiLEAST64 = __PRI64_PREFIX ++ "i";
pub const SCNiFAST8 = "hhi";
pub const SCNiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST64 = __PRI64_PREFIX ++ "i";
pub const SCNu8 = "hhu";
pub const SCNu16 = "hu";
pub const SCNu32 = "u";
pub const SCNu64 = __PRI64_PREFIX ++ "u";
pub const SCNuLEAST8 = "hhu";
pub const SCNuLEAST16 = "hu";
pub const SCNuLEAST32 = "u";
pub const SCNuLEAST64 = __PRI64_PREFIX ++ "u";
pub const SCNuFAST8 = "hhu";
pub const SCNuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST64 = __PRI64_PREFIX ++ "u";
pub const SCNo8 = "hho";
pub const SCNo16 = "ho";
pub const SCNo32 = "o";
pub const SCNo64 = __PRI64_PREFIX ++ "o";
pub const SCNoLEAST8 = "hho";
pub const SCNoLEAST16 = "ho";
pub const SCNoLEAST32 = "o";
pub const SCNoLEAST64 = __PRI64_PREFIX ++ "o";
pub const SCNoFAST8 = "hho";
pub const SCNoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST64 = __PRI64_PREFIX ++ "o";
pub const SCNx8 = "hhx";
pub const SCNx16 = "hx";
pub const SCNx32 = "x";
pub const SCNx64 = __PRI64_PREFIX ++ "x";
pub const SCNxLEAST8 = "hhx";
pub const SCNxLEAST16 = "hx";
pub const SCNxLEAST32 = "x";
pub const SCNxLEAST64 = __PRI64_PREFIX ++ "x";
pub const SCNxFAST8 = "hhx";
pub const SCNxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST64 = __PRI64_PREFIX ++ "x";
pub const SCNdMAX = __PRI64_PREFIX ++ "d";
pub const SCNiMAX = __PRI64_PREFIX ++ "i";
pub const SCNoMAX = __PRI64_PREFIX ++ "o";
pub const SCNuMAX = __PRI64_PREFIX ++ "u";
pub const SCNxMAX = __PRI64_PREFIX ++ "x";
pub const SCNdPTR = __PRIPTR_PREFIX ++ "d";
pub const SCNiPTR = __PRIPTR_PREFIX ++ "i";
pub const SCNoPTR = __PRIPTR_PREFIX ++ "o";
pub const SCNuPTR = __PRIPTR_PREFIX ++ "u";
pub const SCNxPTR = __PRIPTR_PREFIX ++ "x";
pub const PLVERSION = @import("std").zig.c_translation.promoteIntLiteral(c_int, 90004, .decimal);
pub const PLVERSION_TAG = "";
pub const PL_FLI_VERSION = @as(c_int, 2);
pub const PL_REC_VERSION = @as(c_int, 3);
pub const PL_QLF_LOADVERSION = @as(c_int, 68);
pub const PL_QLF_VERSION = @as(c_int, 68);
pub const _PL_EXPORT_DONE = "";
pub const PL_EXPORT = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:136:9
pub const PL_EXPORT_DATA = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:137:9
pub const install_t = anyopaque;
// Commented out: unable to translate these macros, not needed for basic FFI
// pub const PL_OPAQUE = @compileError("unable to translate macro: undefined identifier `__PL_`");
// // /usr/lib/swi-prolog/include/SWI-Prolog.h:151:9
// pub const _DEFINED_PL_OPAQUE = "";
// pub inline fn PL_STRUCT(name: anytype) @TypeOf(struct_PL_OPAQUE(name)) {
//     _ = &name;
//     return struct_PL_OPAQUE(name);
// }
// pub const _DEFINED_PL_STRUCT = "";
// pub const _PLQ = PL_OPAQUE;
// pub const _PLS = PL_STRUCT;
pub const WUNUSED = @compileError("unable to translate macro: undefined identifier `warn_unused_result`");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:172:9
pub const PL_HAVE_TERM_T = "";
pub const fid_t = PL_fid_t;
pub const TRUE = @as(c_int, 1);
pub const FALSE = @as(c_int, 0);
pub const PL_VARIABLE = @as(c_int, 1);
pub const PL_ATOM = @as(c_int, 2);
pub const PL_INTEGER = @as(c_int, 3);
pub const PL_RATIONAL = @as(c_int, 4);
pub const PL_FLOAT = @as(c_int, 5);
pub const PL_STRING = @as(c_int, 6);
pub const PL_TERM = @as(c_int, 7);
pub const PL_NIL = @as(c_int, 8);
pub const PL_BLOB = @as(c_int, 9);
pub const PL_LIST_PAIR = @as(c_int, 10);
pub const PL_FUNCTOR = @as(c_int, 11);
pub const PL_LIST = @as(c_int, 12);
pub const PL_CHARS = @as(c_int, 13);
pub const PL_POINTER = @as(c_int, 14);
pub const PL_CODE_LIST = @as(c_int, 15);
pub const PL_CHAR_LIST = @as(c_int, 16);
pub const PL_BOOL = @as(c_int, 17);
pub const PL_FUNCTOR_CHARS = @as(c_int, 18);
pub const _PL_PREDICATE_INDICATOR = @as(c_int, 19);
pub const PL_SHORT = @as(c_int, 20);
pub const PL_INT = @as(c_int, 21);
pub const PL_LONG = @as(c_int, 22);
pub const PL_DOUBLE = @as(c_int, 23);
pub const PL_NCHARS = @as(c_int, 24);
pub const PL_UTF8_CHARS = @as(c_int, 25);
pub const PL_UTF8_STRING = @as(c_int, 26);
pub const PL_INT64 = @as(c_int, 27);
pub const PL_NUTF8_CHARS = @as(c_int, 28);
pub const PL_NUTF8_CODES = @as(c_int, 29);
pub const PL_NUTF8_STRING = @as(c_int, 30);
pub const PL_NWCHARS = @as(c_int, 31);
pub const PL_NWCODES = @as(c_int, 32);
pub const PL_NWSTRING = @as(c_int, 33);
pub const PL_MBCHARS = @as(c_int, 34);
pub const PL_MBCODES = @as(c_int, 35);
pub const PL_MBSTRING = @as(c_int, 36);
pub const PL_INTPTR = @as(c_int, 37);
pub const PL_CHAR = @as(c_int, 38);
pub const PL_CODE = @as(c_int, 39);
pub const PL_BYTE = @as(c_int, 40);
pub const PL_PARTIAL_LIST = @as(c_int, 41);
pub const PL_CYCLIC_TERM = @as(c_int, 42);
pub const PL_NOT_A_LIST = @as(c_int, 43);
pub const PL_DICT = @as(c_int, 44);
pub const FF_READONLY = @as(c_int, 0x1000);
pub const FF_KEEP = @as(c_int, 0x2000);
pub const FF_NOCREATE = @as(c_int, 0x4000);
pub const FF_FORCE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x8000, .hex);
pub const FF_MASK = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xf000, .hex);
pub const PL_succeed = @compileError("unable to translate C expr: unexpected token 'return'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:297:9
pub const PL_fail = @compileError("unable to translate C expr: unexpected token 'return'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:298:9
pub const PL_FIRST_CALL = @as(c_int, 0);
pub const PL_CUTTED = @as(c_int, 1);
pub const PL_PRUNED = @as(c_int, 1);
pub const PL_REDO = @as(c_int, 2);
pub const PL_RESUME = @as(c_int, 3);
pub const PL_retry = @compileError("unable to translate C expr: unexpected token 'return'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:318:9
pub const PL_retry_address = @compileError("unable to translate C expr: unexpected token 'return'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:319:9
pub const PL_yield_address = @compileError("unable to translate C expr: unexpected token 'return'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:320:9
pub const PL_FA_NOTRACE = @as(c_int, 0x01);
pub const PL_FA_TRANSPARENT = @as(c_int, 0x02);
pub const PL_FA_NONDETERMINISTIC = @as(c_int, 0x04);
pub const PL_FA_VARARGS = @as(c_int, 0x08);
pub const PL_FA_CREF = @as(c_int, 0x10);
pub const PL_FA_ISO = @as(c_int, 0x20);
pub const PL_FA_META = @as(c_int, 0x40);
pub const PL_FA_SIG_ATOMIC = @as(c_int, 0x80);
pub const ATOM_nil = _PL_atoms()[@as(usize, @intCast(@as(c_int, 0)))];
pub const ATOM_dot = _PL_atoms()[@as(usize, @intCast(@as(c_int, 1)))];
pub const PL_Q_NORMAL = @as(c_int, 0x0002);
pub const PL_Q_NODEBUG = @as(c_int, 0x0004);
pub const PL_Q_CATCH_EXCEPTION = @as(c_int, 0x0008);
pub const PL_Q_PASS_EXCEPTION = @as(c_int, 0x0010);
pub const PL_Q_ALLOW_YIELD = @as(c_int, 0x0020);
pub const PL_Q_EXT_STATUS = @as(c_int, 0x0040);
pub const PL_S_EXCEPTION = -@as(c_int, 1);
pub const PL_S_FALSE = @as(c_int, 0);
pub const PL_S_TRUE = @as(c_int, 1);
pub const PL_S_LAST = @as(c_int, 2);
pub const PL_S_YIELD = @as(c_int, 255);
pub const PL_ASSERTZ = @as(c_int, 0x0000);
pub const PL_ASSERTA = @as(c_int, 0x0001);
pub const PL_CREATE_THREAD_LOCAL = @as(c_int, 0x0010);
pub const PL_CREATE_INCREMENTAL = @as(c_int, 0x0020);
pub inline fn PL_get_string_chars(t: anytype, s: anytype, l: anytype) @TypeOf(PL_get_string(t, s, l)) {
    _ = &t;
    _ = &s;
    _ = &l;
    return PL_get_string(t, s, l);
}
pub const PL_BLOB_MAGIC_B = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x75293a00, .hex);
pub const PL_BLOB_VERSION = @as(c_int, 1);
pub const PL_BLOB_MAGIC = PL_BLOB_MAGIC_B | PL_BLOB_VERSION;
pub const PL_BLOB_UNIQUE = @as(c_int, 0x01);
pub const PL_BLOB_TEXT = @as(c_int, 0x02);
pub const PL_BLOB_NOCOPY = @as(c_int, 0x04);
pub const PL_BLOB_WCHAR = @as(c_int, 0x08);
pub const PL_FILE_ABSOLUTE = @as(c_int, 0x01);
pub const PL_FILE_OSPATH = @as(c_int, 0x02);
pub const PL_FILE_SEARCH = @as(c_int, 0x04);
pub const PL_FILE_EXIST = @as(c_int, 0x08);
pub const PL_FILE_READ = @as(c_int, 0x10);
pub const PL_FILE_WRITE = @as(c_int, 0x20);
pub const PL_FILE_EXECUTE = @as(c_int, 0x40);
pub const PL_FILE_NOERRORS = @as(c_int, 0x80);
pub const PL_set_feature = PL_set_prolog_flag;
pub const CVT_ATOM = @as(c_int, 0x00000001);
pub const CVT_STRING = @as(c_int, 0x00000002);
pub const CVT_LIST = @as(c_int, 0x00000004);
pub const CVT_INTEGER = @as(c_int, 0x00000008);
pub const CVT_RATIONAL = @as(c_int, 0x00000010);
pub const CVT_FLOAT = @as(c_int, 0x00000020);
pub const CVT_VARIABLE = @as(c_int, 0x00000040);
pub const CVT_NUMBER = CVT_RATIONAL | CVT_FLOAT;
pub const CVT_ATOMIC = (CVT_NUMBER | CVT_ATOM) | CVT_STRING;
pub const CVT_WRITE = @as(c_int, 0x00000080);
pub const CVT_WRITE_CANONICAL = @as(c_int, 0x00000100);
pub const CVT_WRITEQ = @as(c_int, 0x00000200);
pub const CVT_ALL = CVT_ATOMIC | CVT_LIST;
pub const CVT_MASK = @as(c_int, 0x00000fff);
pub const CVT_EXCEPTION = @as(c_int, 0x00001000);
pub const CVT_VARNOFAIL = @as(c_int, 0x00002000);
pub const BUF_DISCARDABLE = @as(c_int, 0x00000000);
pub const BUF_STACK = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00010000, .hex);
pub const BUF_MALLOC = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00020000, .hex);
pub const BUF_ALLOW_STACK = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00040000, .hex);
pub const BUF_RING = BUF_STACK;
pub const REP_ISO_LATIN_1 = @as(c_int, 0x00000000);
pub const REP_UTF8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00100000, .hex);
pub const REP_MB = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00200000, .hex);
pub const REP_FN = REP_MB;
pub const PL_DIFF_LIST = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const PL_STRINGS_MARK = @compileError("unable to translate macro: undefined identifier `__PL_mark`");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:920:9
pub const PL_STRINGS_RELEASE = @compileError("unable to translate macro: undefined identifier `__PL_mark`");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:923:9
pub const PL_open_stream = PL_unify_stream;
pub const Suser_input = _PL_streams()[@as(usize, @intCast(@as(c_int, 0)))];
pub const Suser_output = _PL_streams()[@as(usize, @intCast(@as(c_int, 1)))];
pub const Suser_error = _PL_streams()[@as(usize, @intCast(@as(c_int, 2)))];
pub const Scurrent_input = _PL_streams()[@as(usize, @intCast(@as(c_int, 3)))];
pub const Scurrent_output = _PL_streams()[@as(usize, @intCast(@as(c_int, 4)))];
pub const PL_WRT_QUOTED = @as(c_int, 0x01);
pub const PL_WRT_IGNOREOPS = @as(c_int, 0x02);
pub const PL_WRT_NUMBERVARS = @as(c_int, 0x04);
pub const PL_WRT_PORTRAY = @as(c_int, 0x08);
pub const PL_WRT_CHARESCAPES = @as(c_int, 0x10);
pub const PL_WRT_BACKQUOTED_STRING = @as(c_int, 0x20);
pub const PL_WRT_ATTVAR_IGNORE = @as(c_int, 0x040);
pub const PL_WRT_ATTVAR_DOTS = @as(c_int, 0x080);
pub const PL_WRT_ATTVAR_WRITE = @as(c_int, 0x100);
pub const PL_WRT_ATTVAR_PORTRAY = @as(c_int, 0x200);
pub const PL_WRT_ATTVAR_MASK = ((PL_WRT_ATTVAR_IGNORE | PL_WRT_ATTVAR_DOTS) | PL_WRT_ATTVAR_WRITE) | PL_WRT_ATTVAR_PORTRAY;
pub const PL_WRT_BLOB_PORTRAY = @as(c_int, 0x400);
pub const PL_WRT_NO_CYCLES = @as(c_int, 0x800);
pub const PL_WRT_NEWLINE = @as(c_int, 0x2000);
pub const PL_WRT_VARNAMES = @as(c_int, 0x4000);
pub const PL_WRT_BACKQUOTE_IS_SYMBOL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x8000, .hex);
pub const PL_WRT_DOTLISTS = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10000, .hex);
pub const PL_WRT_BRACETERMS = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x20000, .hex);
pub const PL_WRT_NODICT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x40000, .hex);
pub const PL_WRT_NODOTINATOM = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x80000, .hex);
pub const PL_WRT_NO_LISTS = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100000, .hex);
pub const PL_WRT_RAT_NATURAL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x200000, .hex);
pub const PL_WRT_CHARESCAPES_UNICODE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x400000, .hex);
pub const PL_WRT_QUOTE_NON_ASCII = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x800000, .hex);
pub const PL_WRT_PARTIAL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000000, .hex);
pub const PL_NOTTY = @as(c_int, 0);
pub const PL_RAWTTY = @as(c_int, 1);
pub const PL_COOKEDTTY = @as(c_int, 2);
pub const PL_CLEANUP_STATUS_MASK = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x0ffff, .hex);
pub const PL_CLEANUP_NO_RECLAIM_MEMORY = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10000, .hex);
pub const PL_CLEANUP_NO_CANCEL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x20000, .hex);
pub const PL_CLEANUP_CANCELED = @as(c_int, 0);
pub const PL_CLEANUP_SUCCESS = @as(c_int, 1);
pub const PL_CLEANUP_FAILED = -@as(c_int, 1);
pub const PL_CLEANUP_RECURSIVE = -@as(c_int, 2);
pub const PL_DISPATCH_NOWAIT = @as(c_int, 0);
pub const PL_DISPATCH_WAIT = @as(c_int, 1);
pub const PL_DISPATCH_INSTALLED = @as(c_int, 2);
pub const PL_DISPATCH_INPUT = @as(c_int, 0);
pub const PL_DISPATCH_TIMEOUT = @as(c_int, 1);
pub const OPT_TYPE_MASK = @as(c_int, 0xff);
pub const OPT_INF = @as(c_int, 0x100);
pub const OPT_ALL = @as(c_int, 0x1);
pub const PL_OPTION = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:1132:9
pub const PL_OPTIONS_END = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/lib/swi-prolog/include/SWI-Prolog.h:1133:9
pub const PL_SIGSYNC = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00010000, .hex);
pub const PL_SIGNOFRAME = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x00020000, .hex);
pub const PLSIG_THROW = @as(c_int, 0x0002);
pub const PLSIG_SYNC = @as(c_int, 0x0004);
pub const PLSIG_NOFRAME = @as(c_int, 0x0008);
pub const PLSIG_IGNORE = @as(c_int, 0x0010);
pub const PL_ACTION_TRACE = @as(c_int, 1);
pub const PL_ACTION_DEBUG = @as(c_int, 2);
pub const PL_ACTION_BACKTRACE = @as(c_int, 3);
pub const PL_ACTION_BREAK = @as(c_int, 4);
pub const PL_ACTION_HALT = @as(c_int, 5);
pub const PL_ACTION_ABORT = @as(c_int, 6);
pub const PL_ACTION_WRITE = @as(c_int, 8);
pub const PL_ACTION_FLUSH = @as(c_int, 9);
pub const PL_ACTION_GUIAPP = @as(c_int, 10);
pub const PL_ACTION_ATTACH_CONSOLE = @as(c_int, 11);
pub const PL_GMP_SET_ALLOC_FUNCTIONS = @as(c_int, 12);
pub const PL_ACTION_TRADITIONAL = @as(c_int, 13);
pub const PL_BT_SAFE = @as(c_int, 0x1);
pub const PL_BT_USER = @as(c_int, 0x2);
pub const PL_VERSION_SYSTEM = @as(c_int, 1);
pub const PL_VERSION_FLI = @as(c_int, 2);
pub const PL_VERSION_REC = @as(c_int, 3);
pub const PL_VERSION_QLF = @as(c_int, 4);
pub const PL_VERSION_QLF_LOAD = @as(c_int, 5);
pub const PL_VERSION_VM = @as(c_int, 6);
pub const PL_VERSION_BUILT_IN = @as(c_int, 7);
pub inline fn PL_version(id: anytype) @TypeOf(PL_version_info(id)) {
    _ = &id;
    return PL_version_info(id);
}
pub const PL_QUERY_ARGC = @as(c_int, 1);
pub const PL_QUERY_ARGV = @as(c_int, 2);
pub const PL_QUERY_GETC = @as(c_int, 5);
pub const PL_QUERY_MAX_INTEGER = @as(c_int, 6);
pub const PL_QUERY_MIN_INTEGER = @as(c_int, 7);
pub const PL_QUERY_MAX_TAGGED_INT = @as(c_int, 8);
pub const PL_QUERY_MIN_TAGGED_INT = @as(c_int, 9);
pub const PL_QUERY_VERSION = @as(c_int, 10);
pub const PL_QUERY_MAX_THREADS = @as(c_int, 11);
pub const PL_QUERY_ENCODING = @as(c_int, 12);
pub const PL_QUERY_USER_CPU = @as(c_int, 13);
pub const PL_QUERY_HALTING = @as(c_int, 14);
pub const PL_THREAD_NO_DEBUG = @as(c_int, 0x01);
pub const PL_THREAD_NOT_DETACHED = @as(c_int, 0x02);
pub const PL_ENGINE_MAIN = @import("std").zig.c_translation.cast(PL_engine_t, @as(c_int, 0x1));
pub const PL_ENGINE_CURRENT = @import("std").zig.c_translation.cast(PL_engine_t, @as(c_int, 0x2));
pub const PL_ENGINE_SET = @as(c_int, 0);
pub const PL_ENGINE_INVAL = @as(c_int, 2);
pub const PL_ENGINE_INUSE = @as(c_int, 3);
pub const PL_HT_NEW = @as(c_int, 0x0001);
pub const PL_HT_UPDATE = @as(c_int, 0x0002);
pub const PL_ARITY_AS_SIZE = @as(c_int, 1);
pub const timeval = struct_timeval;
pub const timespec = struct_timespec;
pub const __pthread_internal_list = struct___pthread_internal_list;
pub const __pthread_internal_slist = struct___pthread_internal_slist;
pub const __pthread_mutex_s = struct___pthread_mutex_s;
pub const __pthread_rwlock_arch_t = struct___pthread_rwlock_arch_t;
pub const __pthread_cond_s = struct___pthread_cond_s;
pub const random_data = struct_random_data;
pub const drand48_data = struct_drand48_data;
pub const __PL_module = struct___PL_module;
pub const __PL_procedure = struct___PL_procedure;
pub const __PL_record = struct___PL_record;
pub const __PL_queryRef = struct___PL_queryRef;
pub const __PL_foreign_context = struct___PL_foreign_context;
pub const __PL_PL_local_data = struct___PL_PL_local_data;
pub const io_stream = struct_io_stream;
pub const pl_sigaction = struct_pl_sigaction;
pub const __PL_table = struct___PL_table;
pub const __PL_table_enum = struct___PL_table_enum;
