import buildopts
import std/random

echo "buildType=", buildType

var x = rand(1.0)
for i in 1..10:
    x *= rand(1.0)
echo "x=", x
