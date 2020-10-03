const std = @import("std");
const Allocator = std.mem.Allocator;

/// Contains all fields of a package,
/// which can then be used for filtering etc.
pub const PackageDescription = struct {
    /// Author of the package
    author: []const u8,
    /// Name of the package
    name: []const u8,
    /// Package can have multiple tags to categorize it
    tags: [][]const u8,
    /// The git url, this can be any url that points towards a git repository
    git: []const u8,
    /// Path to the root file, which `build.zig` can use to add the package to itself
    root_file: []const u8,
    /// Package description
    description: []const u8,
};

/// Struct containing a list of all parsed packages,
/// contains usefull functions to refresh or filter them.
pub const PackageList = struct {
    /// internal list of all packages
    internal: std.ArrayList(PackageDescription),
    /// reference to allocator, used for parsing packages and freeing its memory
    gpa: *Allocator,

    pub fn init(allocator: *Allocator) PackageList {
        return .{
            .internal = std.ArrayList(PackageDescription).init(allocator),
            .gpa = allocator,
        };
    }

    /// Returns a list of packages based on the provided filter
    /// Caller owns memory
    pub fn filter(self: PackageList, comptime field_name: []const u8, value: []const u8) ![]PackageDescription {
        var list = std.ArrayList(PackageDescription).init(self.gpa);
        defer list.deinit();

        for (self.internal.items) |pkg| {
            if (!@hasField(PackageDescription, field_name)) continue;

            if (@TypeOf(@field(pkg, field_name)) == []const u8) {
                if (std.ascii.eqlIgnoreCase(@field(pkg, field_name), value))
                    try list.append(pkg);
                continue;
            }

            if (@TypeOf(@field(pkg, field_name)) == [][]const u8) {
                for (@field(pkg, field_name)) |tag| {
                    if (std.ascii.eqlIgnoreCase(tag, value)) {
                        try list.append(pkg);
                        continue;
                    }
                }
            }
        }

        return list.toOwnedSlice();
    }

    /// Creates a new PackageList from a stream that contains the raw data
    /// The content must be json and correct.
    pub fn fromStream(allocator: *Allocator, reader: anytype) !PackageList {}

    pub fn deinit(self: PackageList) void {
        self.internal.deinit();
    }
};

test "Filter packages" {
    const test_package =
        \\  {
        \\      "author": "xq",
        \\      "root_file": "src/root.zig",
        \\      "tags": [ "sdl", "sdl2", "game", "graphics" ],
        \\      "git": "https://github.com/MasterQ32/SDL.zig",
        \\      "name": "SDL2",
        \\      "description": "Wraps SDL2 into a nice and cozy zig-style API."
        \\  }
    ;

    const gpa = std.testing.allocator;

    var opts = std.json.ParseOptions{ .allocator = gpa, .duplicate_field_behavior = .Error };
    var stream = std.json.TokenStream.init(test_package);

    const pkg = try std.json.parse(PackageDescription, &stream, opts);
    defer std.json.parseFree(PackageDescription, pkg, opts);

    var list = PackageList.init(gpa);
    defer list.deinit();
    try list.internal.append(pkg);

    const filtered_list = try list.filter("author", "xq");
    defer gpa.free(filtered_list);

    std.testing.expectEqual(@as(usize, 1), filtered_list.len);
    std.testing.expectEqualStrings(pkg.description, filtered_list[0].description);
}
