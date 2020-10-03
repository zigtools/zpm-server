const std = @import("std");
const pkg = @import("package.zig");

const path = @import("build_options").packages_dir;
const Self = @This();

packages: pkg.PackageList,
gpa: *std.mem.Allocator,
opts: std.json.ParseOptions,

/// Initializes the package list, will retrieve all packages
/// found in `path` provided by 'build.zig'
pub fn init(allocator: *std.mem.Allocator) !Self {
    var self = Self{
        .packages = pkg.PackageList.init(allocator),
        .gpa = allocator,
        .opts = std.json.ParseOptions{ .allocator = allocator, .duplicate_field_behavior = .Error },
    };

    try parseDirectory(&self);
    return self;
}

/// Frees all memory of the parsed json package files
pub fn deinit(self: Self) void {
    for (self.packages.internal.items) |item| {
        std.json.parseFree(pkg.PackageDescription, item, self.opts);
        self.gpa.free(item.name);
    }

    self.packages.deinit();
}

/// Opens `path` and parses all json files and appends
/// the package to the package list
fn parseDirectory(self: *Self) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != std.fs.Dir.Entry.Kind.File or !std.mem.endsWith(u8, entry.name, ".json")) continue;

        const file = try dir.openFile(entry.name, .{});
        defer file.close();

        const file_contents = try file.readToEndAlloc(self.gpa, std.math.maxInt(u64));
        defer self.gpa.free(file_contents);

        var stream = std.json.TokenStream.init(file_contents);
        var parsed_pkg = try std.json.parse(pkg.PackageDescription, &stream, self.opts);
        parsed_pkg.name = try self.gpa.dupe(u8, entry.name[0 .. entry.name.len - 5]);
        try self.packages.internal.append(parsed_pkg);
    }
}
