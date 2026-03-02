import buildopts
import std/tables

proc show(value: int) =
  echo "count=", value

proc show(value: string) =
  echo "item=", value

echo "buildType=", buildType

var numbers = @[3, 5, 8]
echo "dynamic array=", numbers

var scores = {"nim": 3, "odin": 2, "zig": 1}.toTable
echo "hashmap entries:"
for name, value in scores.pairs:
  echo "  ", name, " -> ", value

echo "overloaded proc calls:"
show(numbers.len)
show("nim")
