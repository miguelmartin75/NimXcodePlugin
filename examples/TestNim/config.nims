import src/buildopts

echo "buildType=", buildType
if buildType == "Debug":
    --debugger:native
    --linedir:on
else:
    assert buildType == "Release"
    --define:release
