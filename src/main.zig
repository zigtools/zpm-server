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
        miniRouter,
    );
}

fn miniRouter(res: *http.Response, req: http.Request) !void {
    try res.headers.put("Content-Type", "application/json");
    try res.headers.put("Access-Control-Allow-Origin", "*");

    const path = req.url.path;

    if (std.mem.startsWith(u8, path, "/packages")) return pkgHandler(res, req);
    if (std.mem.startsWith(u8, path, "/tags")) return tagHandler(res, req);

    return index(res, req);
}

/// Api handler
fn pkgHandler(res: *http.Response, req: http.Request) !void {
    var query = try req.url.queryParameters(&gpa.allocator);
    var filtered = package_cache.packages.filter();

    var it = query.iterator();
    while (it.next()) |entry| filtered.filter(entry.key, entry.value);

    try writeAsJson(pkg.PackageDescription, filtered.result(), res.writer());
    // flush to ensure user recieves response before we potentially refresh cache
    try res.flush();
    try package_cache.updateCache();
}

/// Tags handler
fn tagHandler(res: *http.Response, req: http.Request) !void {
    const tags = package_cache.tags.items;
    try writeAsJson(pkg.Tag, tags, res.writer());
    try res.flush();
    try package_cache.updateCache();
}

/// Index page, showing the API scheme
fn index(res: *http.Response, req: http.Request) !void {
    try res.writer().writeAll(
        \\{
        \\  "endpoints": [
        \\      "/",
        \\      "/packages",
        \\      "/tags"
        \\  ],
        \\  "objects": [
        \\      "package",
        \\      "tag"
        \\  ],
        \\  "package": [
        \\      "author",
        \\      "name",
        \\      "description",
        \\      "tags",
        \\      "git",
        \\      "root_file"
        \\  ],
        \\  "tag": [
        \\      "name",
        \\      "description"
        \\  ]
        \\}
    );
}

/// Writes the packages as json to the given writer stream
fn writeAsJson(comptime T: type, list: []const T, writer: anytype) @TypeOf(writer).Error!void {
    var json = std.json.writeStream(writer, 22);
    try json.beginArray();
    for (list) |item| {
        try json.arrayElem();
        try json.beginObject();
        inline for (@typeInfo(T).Struct.fields) |field| {
            try json.objectField(field.name);

            const cur_field = @field(item, field.name);

            if (@TypeOf(cur_field) == []const u8) {
                try json.emitString(cur_field);
            }

            if (@TypeOf(cur_field) == [][]const u8) {
                try json.beginArray();
                for (cur_field) |tag| {
                    try json.arrayElem();
                    try json.emitString(tag);
                }
                try json.endArray();
            }

            if (@TypeOf(cur_field) == ?[]const u8) {
                if (cur_field) |val|
                    try json.emitString(val)
                else
                    try json.emitNull();
            }
        }
        try json.endObject();
    }
    try json.endArray();
}
