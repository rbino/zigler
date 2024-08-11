# Global module options

## ignore

Public functions can be ignored and *not* converted into nifs by filling out the `:ignore` option in
`use Zig` directive.

```elixir
defmodule IgnoreTest do
  use ExUnit.Case, async: true

  use Zig, 
    otp_app: :zigler,
    ignore: [:ignored]

  ~Z"""
  pub fn ignored(number: u32) u32 {
      return number + 1;
  }

  pub fn available(number: u32) u32 {
      return ignored(number);
  }
  """

  test "available function works" do
    assert 48 = available(47)
  end

  test "ignored function is not available" do
    refute function_exported?(__MODULE__, :ignored, 0)
  end
end
```

## attributes

Attributes from your module can be used as compile-time constants communicated 
from elixir.  All attributes of the following types will be automatically 
available through the `attributes` module import:

- `integer` (as `comptime int` values)
- `float` (as `comptime float` values)
- `nil` (as `null`)
- `boolean` (as `bool` values)
- `binary` (as `comptime [:0]u8` values)
- `atom` (as *enum literal* values)
- `tuple` of only the above types (as *tuple*)

```elixir
defmodule Attribute do
  use ExUnit.Case, async: true
  use Zig, otp_app: :zigler

  @supplied_value Mix.env()

  ~Z"""
  const beam = @import("beam");
  const attribs = @import("attributes");

  pub fn get_attrib() beam.term {
    return beam.make(.{.ok, attribs.supplied_value}, .{});
  }
  """

  test "getting an attribute" do
    assert {:ok, :test} = get_attrib()
  end
end
```

## adding packages

It's possible to add zig files as packages using the `packages` keyword option. The name of the
package is the key, and the value is a tuple of the path to the zig file that acts as the package
and a list of dependencies for the package. 

### Example extra.zig

```zig
pub const value = 47;
```

```elixir
defmodule PackageFile do
  use ExUnit.Case, async: true
  use Zig, 
    otp_app: :zigler,
    packages: [extra: {"test/_support/package/extra.zig", [:beam]}]

  ~Z"""
  const extra = @import("extra");

  pub fn extra_value() u64 {
    return extra.value;
  }
  """

  test "package file" do
    assert 47 = extra_value()
  end
end
#module
```

## dump options

Zigler lets you dump various compile-time assets to the console for
debugging purposes, which can be enabled by setting any given one
of the following options to `true`:

- `dump`: dumps the rendered elixir code generated by `use Zig`.
- `dump_sema`: dumps the json data emitted by the semantic analysis pass.
- `dump_build_zig`: dumps the autogenerated `build.zig` file