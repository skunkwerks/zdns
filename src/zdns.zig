const FILE = @import("std").c.FILE;

pub fn ErrUnion(comptime t: type) type {
    return union(enum) {
        err: status,
        ok: t,

        pub fn init(result: t, stat: status) @This() {
            return if (stat == .OK)
                .{ .ok = result }
            else
                .{ .err = stat };
        }
    };
}

pub const Oom = error{OutOfMemory};

pub const zone = opaque {
    extern fn ldns_zone_new_frm_fp_l(z: ?**zone, fp: *FILE, origin: ?*const rdf, ttl: u32, c: rr_class, line_nr: *c_int) status;

    pub const NewFrmFpDiagnostic = struct {
        code: status,
        line: c_int,
    };

    pub const NewFrmFpResult = union(enum) {
        err: NewFrmFpDiagnostic,
        ok: *zone,
    };

    pub fn new_frm_fp(fp: *FILE, origin: ?*const rdf, ttl: u32, c: rr_class) NewFrmFpResult {
        var z: *zone = undefined;
        var line: c_int = 0;
        const stat = ldns_zone_new_frm_fp_l(&z, fp, origin, ttl, c, &line);
        if (stat == .OK) {
            return .{ .ok = z };
        } else {
            return .{ .err = .{ .code = stat, .line = line } };
        }
    }

    extern fn ldns_zone_soa(z: *const zone) ?*rr;
    pub const soa = ldns_zone_soa;

    extern fn ldns_zone_rrs(z: *const zone) *rr_list;
    pub const rrs = ldns_zone_rrs;

    extern fn ldns_zone_deep_free(zone: *zone) void;
    pub const deep_free = ldns_zone_deep_free;
};

pub const rr = opaque {
    extern fn ldns_rr_owner(row: *const rr) *rdf;
    pub const owner = ldns_rr_owner;

    extern fn ldns_rr_ttl(row: *const rr) u32;
    pub const ttl = ldns_rr_ttl;

    extern fn ldns_rr_get_type(row: *const rr) rr_type;
    pub const get_type = ldns_rr_get_type;

    extern fn ldns_rr_rd_count(row: *const rr) usize;
    pub const rd_count = ldns_rr_rd_count;

    extern fn ldns_rr_rdf(row: *const rr, nr: usize) ?*rdf;

    pub fn rdf(row: *const rr, nr: usize) *rdf {
        return row.ldns_rr_rdf(nr).?; // null on out of bounds
    }

    extern fn ldns_rr_new_frm_str(n: ?**rr, str: [*:0]const u8, default_ttl: u32, origin: ?*const rdf, prev: ?*?*rdf) status;
    pub fn new_frm_str(str: [*:0]const u8, default_ttl: u32, origin: ?*const rdf, prev: ?*?*rdf) ErrUnion(*rr){
        var row: *rr = undefined;
        const stat = ldns_rr_new_frm_str(&row, str, default_ttl, origin, null);
        return ErrUnion(*rr).init(row, stat);
    }

    extern fn ldns_rr_free(row: *rr) void;
    pub const free = ldns_rr_free;
};

pub const rr_list = opaque {
    extern fn ldns_rr_list_rr_count(list: *const rr_list) usize;
    pub const rr_count = ldns_rr_list_rr_count;

    extern fn ldns_rr_list_rr(list: *const rr_list, nr: usize) ?*rr;

    pub fn rr(list: *const rr_list, nr: usize) *rr {
        return list.ldns_rr_list_rr(nr).?; // null on out of bounds
    }
};

pub const rdf = opaque {
    extern fn ldns_rdf_get_type(rd: *const rdf) rdf_type;
    pub const get_type = ldns_rdf_get_type;

    extern fn ldns_rdf2buffer_str(output: *buffer, rdf: *const rdf) status;

    pub fn appendStr(rd: *const rdf, output: *buffer) status {
        return ldns_rdf2buffer_str(output, rd);
    }

    extern fn ldns_rdf2native_int8(rd: *const rdf) u8;
    pub const int8 = ldns_rdf2native_int8;

    extern fn ldns_rdf2native_int16(rd: *const rdf) u16;
    pub const int16 = ldns_rdf2native_int16;

    extern fn ldns_rdf2native_int32(rd: *const rdf) u32;
    pub const int32 = ldns_rdf2native_int32;

    extern fn ldns_rdf_new_frm_str(type_: rdf_type, str: [*:0]const u8) ?*rdf;
    pub const new_frm_str = ldns_rdf_new_frm_str;

    extern fn ldns_rdf_deep_free(rd: *rdf) void;
    pub const deep_free = ldns_rdf_deep_free;
};

pub const buffer = opaque {
    extern fn ldns_buffer_new(capacity: usize) ?*buffer;

    pub fn new(capacity: usize) Oom!*buffer {
        return ldns_buffer_new(capacity) orelse error.OutOfMemory;
    }

    extern fn ldns_buffer_free(buffer: *buffer) void;
    pub const free = ldns_buffer_free;

    pub fn clear(buf: *buffer) void {
        const casted = @ptrCast(*buffer_struct, @alignCast(@alignOf(buffer_struct), buf));
        casted._position = 0;
        casted._limit = casted._capacity;
    }

    pub fn data(buf: *buffer) []u8 {
        const casted = @ptrCast(*buffer_struct, @alignCast(@alignOf(buffer_struct), buf));
        return casted._data[0..casted._position];
    }
};

// TODO when zig translate-c supports bitfields fix this
const buffer_struct = extern struct {
    // The current position used for reading/writing
    _position: usize,

    // The read/write limit
    _limit: usize,

    // The amount of data the buffer can contain
    _capacity: usize,

    // The data contained in the buffer
    _data: [*]u8,

    // If the buffer is fixed it cannot be resized
    //unsigned _fixed : 1;

    // The current state of the buffer. If writing to the buffer fails
    // for any reason, this value is changed. This way, you can perform
    // multiple writes in sequence and check for success afterwards.
    //status _status;
};

pub const rr_class = extern enum(c_int) {
    IN = 1,
    CH = 3,
    HS = 4,
    NONE = 254,
    ANY = 255,
    FIRST = 0,
    LAST = 65535,
    COUNT = 65536,
    _,
};

pub const rr_type = extern enum(c_int) {
    A = 1,
    NS = 2,
    MD = 3,
    MF = 4,
    CNAME = 5,
    SOA = 6,
    MB = 7,
    MG = 8,
    MR = 9,
    NULL = 10,
    WKS = 11,
    PTR = 12,
    HINFO = 13,
    MINFO = 14,
    MX = 15,
    TXT = 16,
    RP = 17,
    AFSDB = 18,
    X25 = 19,
    ISDN = 20,
    RT = 21,
    NSAP = 22,
    NSAP_PTR = 23,
    SIG = 24,
    KEY = 25,
    PX = 26,
    GPOS = 27,
    AAAA = 28,
    LOC = 29,
    NXT = 30,
    EID = 31,
    NIMLOC = 32,
    SRV = 33,
    ATMA = 34,
    NAPTR = 35,
    KX = 36,
    CERT = 37,
    A6 = 38,
    DNAME = 39,
    SINK = 40,
    OPT = 41,
    APL = 42,
    DS = 43,
    SSHFP = 44,
    IPSECKEY = 45,
    RRSIG = 46,
    NSEC = 47,
    DNSKEY = 48,
    DHCID = 49,
    NSEC3 = 50,
    NSEC3PARAM = 51,
    NSEC3PARAMS = 51,
    TLSA = 52,
    SMIMEA = 53,
    HIP = 55,
    NINFO = 56,
    RKEY = 57,
    TALINK = 58,
    CDS = 59,
    CDNSKEY = 60,
    OPENPGPKEY = 61,
    CSYNC = 62,
    ZONEMD = 63,
    SPF = 99,
    UINFO = 100,
    UID = 101,
    GID = 102,
    UNSPEC = 103,
    NID = 104,
    L32 = 105,
    L64 = 106,
    LP = 107,
    EUI48 = 108,
    EUI64 = 109,
    TKEY = 249,
    TSIG = 250,
    IXFR = 251,
    AXFR = 252,
    MAILB = 253,
    MAILA = 254,
    ANY = 255,
    URI = 256,
    CAA = 257,
    AVC = 258,
    DOA = 259,
    AMTRELAY = 260,
    TA = 32768,
    DLV = 32769,
    FIRST = 0,
    LAST = 65535,
    COUNT = 65536,
    _,

    extern fn ldns_rr_type2buffer_str(output: *buffer, type_: rr_type) status;

    pub fn appendStr(type_: rr_type, output: *buffer) status {
        return ldns_rr_type2buffer_str(output, type_);
    }
};

pub const rdf_type = extern enum(c_int) {
    NONE = 0,
    DNAME = 1,
    INT8 = 2,
    INT16 = 3,
    INT32 = 4,
    A = 5,
    AAAA = 6,
    STR = 7,
    APL = 8,
    B32_EXT = 9,
    B64 = 10,
    HEX = 11,
    NSEC = 12,
    TYPE = 13,
    CLASS = 14,
    CERT_ALG = 15,
    ALG = 16,
    UNKNOWN = 17,
    TIME = 18,
    PERIOD = 19,
    TSIGTIME = 20,
    HIP = 21,
    INT16_DATA = 22,
    SERVICE = 23,
    LOC = 24,
    WKS = 25,
    NSAP = 26,
    ATMA = 27,
    IPSECKEY = 28,
    NSEC3_SALT = 29,
    NSEC3_NEXT_OWNER = 30,
    ILNP64 = 31,
    EUI48 = 32,
    EUI64 = 33,
    TAG = 34,
    LONG_STR = 35,
    CERTIFICATE_USAGE = 36,
    SELECTOR = 37,
    MATCHING_TYPE = 38,
    AMTRELAY = 39,
    BITMAP = 12,
    _,
};

pub const status = extern enum(c_int) {
    OK,
    EMPTY_LABEL,
    LABEL_OVERFLOW,
    DOMAINNAME_OVERFLOW,
    DOMAINNAME_UNDERFLOW,
    DDD_OVERFLOW,
    PACKET_OVERFLOW,
    INVALID_POINTER,
    MEM_ERR,
    INTERNAL_ERR,
    SSL_ERR,
    ERR,
    INVALID_INT,
    INVALID_IP4,
    INVALID_IP6,
    INVALID_STR,
    INVALID_B32_EXT,
    INVALID_B64,
    INVALID_HEX,
    INVALID_TIME,
    NETWORK_ERR,
    ADDRESS_ERR,
    FILE_ERR,
    UNKNOWN_INET,
    NOT_IMPL,
    NULL,
    CRYPTO_UNKNOWN_ALGO,
    CRYPTO_ALGO_NOT_IMPL,
    CRYPTO_NO_RRSIG,
    CRYPTO_NO_DNSKEY,
    CRYPTO_NO_TRUSTED_DNSKEY,
    CRYPTO_NO_DS,
    CRYPTO_NO_TRUSTED_DS,
    CRYPTO_NO_MATCHING_KEYTAG_DNSKEY,
    CRYPTO_VALIDATED,
    CRYPTO_BOGUS,
    CRYPTO_SIG_EXPIRED,
    CRYPTO_SIG_NOT_INCEPTED,
    CRYPTO_TSIG_BOGUS,
    CRYPTO_TSIG_ERR,
    CRYPTO_EXPIRATION_BEFORE_INCEPTION,
    CRYPTO_TYPE_COVERED_ERR,
    ENGINE_KEY_NOT_LOADED,
    NSEC3_ERR,
    RES_NO_NS,
    RES_QUERY,
    WIRE_INCOMPLETE_HEADER,
    WIRE_INCOMPLETE_QUESTION,
    WIRE_INCOMPLETE_ANSWER,
    WIRE_INCOMPLETE_AUTHORITY,
    WIRE_INCOMPLETE_ADDITIONAL,
    NO_DATA,
    CERT_BAD_ALGORITHM,
    SYNTAX_TYPE_ERR,
    SYNTAX_CLASS_ERR,
    SYNTAX_TTL_ERR,
    SYNTAX_INCLUDE_ERR_NOTIMPL,
    SYNTAX_RDATA_ERR,
    SYNTAX_DNAME_ERR,
    SYNTAX_VERSION_ERR,
    SYNTAX_ALG_ERR,
    SYNTAX_KEYWORD_ERR,
    SYNTAX_TTL,
    SYNTAX_ORIGIN,
    SYNTAX_INCLUDE,
    SYNTAX_EMPTY,
    SYNTAX_ITERATIONS_OVERFLOW,
    SYNTAX_MISSING_VALUE_ERR,
    SYNTAX_INTEGER_OVERFLOW,
    SYNTAX_BAD_ESCAPE,
    SOCKET_ERROR,
    SYNTAX_ERR,
    DNSSEC_EXISTENCE_DENIED,
    DNSSEC_NSEC_RR_NOT_COVERED,
    DNSSEC_NSEC_WILDCARD_NOT_COVERED,
    DNSSEC_NSEC3_ORIGINAL_NOT_FOUND,
    MISSING_RDATA_FIELDS_RRSIG,
    MISSING_RDATA_FIELDS_KEY,
    CRYPTO_SIG_EXPIRED_WITHIN_MARGIN,
    CRYPTO_SIG_NOT_INCEPTED_WITHIN_MARGIN,
    DANE_STATUS_MESSAGES,
    DANE_UNKNOWN_CERTIFICATE_USAGE,
    DANE_UNKNOWN_SELECTOR,
    DANE_UNKNOWN_MATCHING_TYPE,
    DANE_UNKNOWN_PROTOCOL,
    DANE_UNKNOWN_TRANSPORT,
    DANE_MISSING_EXTRA_CERTS,
    DANE_EXTRA_CERTS_NOT_USED,
    DANE_OFFSET_OUT_OF_RANGE,
    DANE_INSECURE,
    DANE_BOGUS,
    DANE_TLSA_DID_NOT_MATCH,
    DANE_NON_CA_CERTIFICATE,
    DANE_PKIX_DID_NOT_VALIDATE,
    DANE_PKIX_NO_SELF_SIGNED_TRUST_ANCHOR,
    EXISTS_ERR,
    INVALID_ILNP64,
    INVALID_EUI48,
    INVALID_EUI64,
    WIRE_RDATA_ERR,
    INVALID_TAG,
    TYPE_NOT_IN_BITMAP,
    INVALID_RDF_TYPE,
    RDATA_OVERFLOW,
    SYNTAX_SUPERFLUOUS_TEXT_ERR,
    NSEC3_DOMAINNAME_OVERFLOW,
    DANE_NEED_OPENSSL_GE_1_1_FOR_DANE_TA,
    _,

    extern fn ldns_get_errorstr_by_id(err: status) ?[*:0]const u8;

    pub fn get_errorstr(err: status) [*:0]const u8 {
        return ldns_get_errorstr_by_id(err).?; // null on invalid
    }
};
