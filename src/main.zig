const std = @import("std");
const http = @import("http");
const pkg = @import("package.zig");

pub const io_mode = .evented;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try http.server.listenAndServe(
        &gpa.allocator,
        try std.net.Address.parseIp("127.0.0.1", 8080),
        api,
    );
}

fn api(res: *http.Response, req: http.Request) !void {
    try res.headers.put("Content-Type", "application/json");
    try res.writer().writeAll(example_json);
}

const example_json =
    \\[
    \\  {
    \\      "author": "xq",
    \\      "root_file": "src/root.zig",
    \\      "tags": [ "sdl", "sdl2", "game", "graphics" ],
    \\      "git": "https://github.com/MasterQ32/SDL.zig",
    \\      "description": "Wraps SDL2 into a nice and cozy zig-style API."
    \\  }
    \\]
;
