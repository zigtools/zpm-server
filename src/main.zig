const std = @import("std");
const http = @import("http");
const pkg = @import("package.zig");
const cache = @import("cache.zig");

pub const io_mode = .evented;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var package_cache: cache = undefined;

pub fn main() !void {
    defer _ = gpa.deinit();

    package_cache = try cache.init(&gpa.allocator);
    defer package_cache.deinit();

    try http.server.listenAndServe(
        &gpa.allocator,
        try std.net.Address.parseIp("0.0.0.0", 8080),
        api,
    );
}

/// Api handler
fn api(res: *http.Response, req: http.Request) !void {
    try res.headers.put("Content-Type", "application/json");

    var query = try req.url.queryParameters(&gpa.allocator);
    var filtered = package_cache.packages.filter();

    var it = query.iterator();
    while (it.next()) |entry| filtered.filter(entry.key, entry.value);

    try writeAsJson(filtered.result(), res.writer());
    // flush to ensure user recieves response before we potentially refresh cache
    try res.flush();
    try package_cache.updateCache();
}

/// Writes the packages as json to the given writer stream
fn writeAsJson(packages: []const pkg.PackageDescription, writer: anytype) @TypeOf(writer).Error!void {
    var json = std.json.writeStream(writer, 22);
    try json.beginArray();
    for (packages) |item| {
        try json.arrayElem();
        try json.beginObject();
        inline for (@typeInfo(pkg.PackageDescription).Struct.fields) |field| {
            try json.objectField(field.name);

            if (@TypeOf(@field(item, field.name)) == []const u8) {
                try json.emitString(@field(item, field.name));
            }

            if (@TypeOf(@field(item, field.name)) == [][]const u8) {
                try json.beginArray();
                for (@field(item, field.name)) |tag| {
                    try json.arrayElem();
                    try json.emitString(tag);
                }
                try json.endArray();
            }
        }
        try json.endObject();
    }
    try json.endArray();
}
