const std = @import("std");
const c = std.c;
const json = std.json;
const ldns = @import("ldns.zig");

extern var stdin: *c.FILE;

pub fn rrFieldNames(type_: ldns.rr_type) []const []const u8 {
    const str = []const u8;
    return switch (type_) {
        .A, .AAAA => &[_]str{"ip"},
        .AFSDB => &[_]str{ "subtype", "hostname" },
        .CAA => &[_]str{ "flags", "tag", "value" },
        .CERT => &[_]str{ "type", "key_tag", "alg", "cert" },
        .CNAME, .DNAME, .NS, .PTR => &[_]str{"dname"},
        .DHCID => &[_]str{"data"},
        .DLV, .DS, .CDS => &[_]str{ "keytag", "alg", "digest_type", "digest" },
        .DNSKEY, .CDNSKEY => &[_]str{ "flags", "protocol", "alg", "public_key", "key_tag" },
        .HINFO => &[_]str{ "cpu", "os" },
        .IPSECKEY => &[_]str{ "precedence", "alg", "gateway", "public_key" },
        .KEY => &[_]str{ "type", "xt", "name_type", "sig", "protocol", "alg", "public_key" },
        .KX, .MX => &[_]str{ "preference", "exchange" },
        .LOC => &[_]str{ "size", "horiz", "vert", "lat", "lon", "alt" },
        .MB, .MG => &[_]str{"madname"},
        .MINFO => &[_]str{ "rmailbx", "emailbx" },
        .MR => &[_]str{"newname"},
        .NAPTR => &[_]str{ "order", "preference", "flags", "services", "regexp", "replacement" },
        .NSEC => &[_]str{ "next_dname", "types" },
        .NSEC3 => &[_]str{ "hash_alg", "opt_out", "iterations", "salt", "hash", "types" },
        .NSEC3PARAM => &[_]str{ "hash_alg", "flags", "iterations", "salt" },
        .NXT => &[_]str{ "dname", "types" },
        .RP => &[_]str{ "mbox", "txt" },
        .RRSIG => &[_]str{ "type_covered", "alg", "labels", "original_ttl", "expiration", "inception", "key_tag", "signers_name", "signature" },
        .RT => &[_]str{ "preference", "host" },
        .SOA => &[_]str{ "mname", "rname", "serial", "refresh", "retry", "expire", "minimum" },
        .SPF => &[_]str{"spf"},
        .SRV => &[_]str{ "priority", "weight", "port", "target" },
        .SSHFP => &[_]str{ "alg", "fp_type", "fp" },
        .TSIG => &[_]str{ "alg", "time", "fudge", "mac", "msgid", "err", "other" },
        .TXT => &[_]str{"txt"},
        else => {
            const buf = ldns.buffer.new(32) catch @panic("oom");
            const status = type_.appendStr(buf);
            status.ok() catch @panic(std.mem.span(status.get_errorstr()));
            std.debug.panic("unsupported record type: {s}", .{buf.data()});
        },
    };
}

pub fn emitRdf(rdf: *ldns.rdf, out: anytype, buf: *ldns.buffer) !void {
    switch (rdf.get_type()) {
        .INT32, .PERIOD => try out.emitNumber(rdf.int32()),
        .INT16 => try out.emitNumber(rdf.int16()),
        .INT8 => try out.emitNumber(rdf.int8()),
        .DNAME => {
            try rdf.appendStr(buf).ok();
            const data = buf.data();
            // strip the trailing dot
            try out.emitString(data[0 .. data.len - 1]);
            buf.clear();
        },
        else => {
            try rdf.appendStr(buf).ok();
            try out.emitString(buf.data());
            buf.clear();
        },
    }
}

pub fn emitRr(rr: *ldns.rr, out: anytype, buf: *ldns.buffer) !void {
    const type_ = rr.get_type();

    try out.beginObject();

    try out.objectField("name");
    try emitRdf(rr.owner(), out, buf);

    try out.objectField("type");
    try type_.appendStr(buf).ok();
    try out.emitString(buf.data());
    buf.clear();

    try out.objectField("ttl");
    try out.emitNumber(rr.ttl());

    try out.objectField("data");
    try out.beginObject();

    const fieldNames = rrFieldNames(type_);

    const rdf_count = rr.rd_count();
    var rdf_index: usize = 0;
    while (rdf_index < rdf_count) : (rdf_index += 1) {
        try out.objectField(fieldNames[rdf_index]);
        try emitRdf(rr.rdf(rdf_index), out, buf);
    }

    try out.endObject();
    try out.endObject();
}

pub fn emitZone(zone: *ldns.zone, out: anytype, buf: *ldns.buffer) !void {
    const rr_list = zone.rrs();
    const rr_count = rr_list.rr_count();

    const soa = if (zone.soa()) |ok| ok else std.debug.panic("no SOA record found", .{});

    try out.beginObject();

    try out.objectField("name");
    try emitRdf(soa.owner(), out, buf);

    try out.objectField("records");
    try out.beginArray();

    try out.arrayElem();
    try emitRr(soa, out, buf);

    var rr_index: usize = 0;
    while (rr_index < rr_count) : (rr_index += 1) {
        const rr = rr_list.rr(rr_index);
        try out.arrayElem();
        try emitRr(rr, out, buf);
    }
    try out.endArray();
    try out.endObject();
}

pub fn main() !void {
    const zone = switch (ldns.zone.new_frm_fp(stdin, null, 0, .IN)) {
        .ok => |z| z,
        .err => |err| std.debug.panic("loading zone failed on line {}: {s}", .{ err.line, err.code.get_errorstr() }),
    };
    defer zone.deep_free();

    var out = json.writeStream(std.io.getStdOut().writer(), 6);

    const buf = try ldns.buffer.new(4096);
    defer buf.free();

    try emitZone(zone, &out, buf);
}
