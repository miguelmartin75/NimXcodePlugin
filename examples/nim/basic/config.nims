import src/buildopts

echo "buildType=", buildType
if buildType == "Debug":
    --define:debug
    --debugger:native
    --linedir:on
else:
    assert buildType == "Release"
    --define:release
