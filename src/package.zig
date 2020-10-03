const std = @import("std");
const Allocator = std.mem.Allocator;

/// Contains all fields of a package,
/// which can then be used for filtering etc.
pub const PackageDescription = struct {
    /// Author of the package
    author: []const u8,
    /// Name of the package
    name: []const u8 = "",
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

    const FilteredList = struct {
        /// all packages, reorderd based on filter calls
        all: []PackageDescription,
        /// slice of .all based on given filter
        filtered: []const PackageDescription,

        /// Filters the `filtered` list by the given query
        pub fn filter(self: *FilteredList, field: []const u8, value: anytype) void {
            var index: usize = 0;
            for (self.filtered) |pkg, i| {
                if (!valid(pkg, field, value)) continue;

                // No need to swap if already at correct index
                if (index == i) {
                    index += 1;
                    continue;
                }

                const temp = self.all[index];
                self.all[i] = temp;
                self.all[index] = pkg;
                index += 1;
            }

            self.filtered = self.all[0..index];
        }

        /// Resets the filter so result() will contain all packages
        pub fn resetFilter(self: *FilteredList) void {
            self.filtered = self.all[0..self.all.len];
        }

        /// Returns a new `FilteredList`
        fn init(list: []PackageDescription) FilteredList {
            return .{
                .all = list,
                .filtered = list,
            };
        }

        /// Checks if the given package complies with the given query
        fn valid(pkg: PackageDescription, field: []const u8, value: []const u8) bool {
            inline for (@typeInfo(PackageDescription).Struct.fields) |pkg_field| {
                if (std.ascii.eqlIgnoreCase(pkg_field.name, field)) {
                    if (@TypeOf(@field(pkg, pkg_field.name)) == []const u8) {
                        if (std.ascii.eqlIgnoreCase(@field(pkg, pkg_field.name), value))
                            return true;
                    }

                    if (@TypeOf(@field(pkg, pkg_field.name)) == [][]const u8) {
                        for (@field(pkg, pkg_field.name)) |tag| {
                            if (std.ascii.eqlIgnoreCase(tag, value)) {
                                return true;
                            }
                        }
                    }
                }
            }
            return false;
        }

        /// Returns the filtered list
        pub fn result(self: FilteredList) []const PackageDescription {
            return self.filtered;
        }
    };

    pub fn init(allocator: *Allocator) PackageList {
        return .{
            .internal = std.ArrayList(PackageDescription).init(allocator),
            .gpa = allocator,
        };
    }

    /// Returns a list of packages based on the provided filter
    /// Caller owns memory
    pub fn filter(self: PackageList) FilteredList {
        return FilteredList.init(self.internal.items[0..]);
    }

    /// Returns an unmutable slice of `PackageDescription`
    pub fn items(self: PackageList) []const PackageDescription {
        return self.internal.items;
    }

    /// Frees the internal packages array list
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
    const test_package2 =
        \\  {
        \\      "author": "foo",
        \\      "root_file": "src/bar.zig",
        \\      "tags": ["game"],
        \\      "git": "https://github.com/foo/bar.zig",
        \\      "name": "foobar",
        \\      "description": "Foo bar is best bar"
        \\  }
    ;

    const gpa = std.testing.allocator;

    var opts = std.json.ParseOptions{ .allocator = gpa, .duplicate_field_behavior = .Error };
    var stream = std.json.TokenStream.init(test_package);
    var stream2 = std.json.TokenStream.init(test_package2);

    const pkg = try std.json.parse(PackageDescription, &stream, opts);
    defer std.json.parseFree(PackageDescription, pkg, opts);

    const pkg2 = try std.json.parse(PackageDescription, &stream2, opts);
    defer std.json.parseFree(PackageDescription, pkg2, opts);

    var list = PackageList.init(gpa);
    defer list.deinit();
    try list.internal.append(pkg);
    try list.internal.append(pkg2);

    var filtered_list = list.filter();
    filtered_list.filter("author", "foo");

    std.testing.expectEqual(@as(usize, 1), filtered_list.filtered.len);
    std.testing.expectEqualStrings(pkg2.description, filtered_list.filtered[0].description);

    filtered_list.resetFilter();
    std.testing.expectEqual(@as(usize, 2), filtered_list.filtered.len);

    filtered_list.filter("tags", "game");
    std.testing.expectEqual(@as(usize, 2), filtered_list.result().len);

    filtered_list.filter("name", "SDL2");
    std.testing.expectEqual(@as(usize, 1), filtered_list.result().len);
    std.testing.expectEqualStrings(pkg.name, filtered_list.result()[0].name);
}
