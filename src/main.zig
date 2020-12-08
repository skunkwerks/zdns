const std = @import("std");
const c = std.c;
const json = std.json;
const ldns = @import("ldns.zig");

extern var stdin: *c.FILE;

pub fn rrFieldNames(type_: ldns.rr_type) []const []const u8 {
    const str = []const u8;
    return switch (type_) {
        .A, .AAAA => &[_]str{"ip"},
        .CNAME, .NS => &[_]str{"dname"},
        .MX => &[_]str{ "preference", "exchange" },
        .SOA => &[_]str{ "mname", "rname", "serial", "refresh", "retry", "expire", "minimum" },
        else => @panic("TODO"),
    };
}

pub fn emitRdf(rdf: *ldns.rdf, out: anytype, buf: *ldns.buffer) !void {
    switch (rdf.get_type()) {
        .INT32, .PERIOD => try out.emitNumber(rdf.int32()),
        .INT16 => try out.emitNumber(rdf.int16()),
        .DNAME => {
            try rdf.appendStr(buf).ok();
            const data = buf.data();
            // strip the trailing dot
            // TODO this is probably wrong for relative dnames
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

    const soa = if (zone.soa()) |ok| ok else @panic("no SOA record");

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
        .err => |status| {
            std.debug.print("{s}\n", .{status.get_errorstr()});
            @panic("loading zone failed");
        },
    };
    defer zone.deep_free();

    var out = json.writeStream(std.io.getStdOut().writer(), 6);

    const buf = try ldns.buffer.new(4096);
    defer buf.free();

    try emitZone(zone, &out, buf);
}
