#!/usr/bin/env bash

set -x

# Create plug-ins directory if it doesn't exist
plugins_dir=~/Library/Developer/Xcode/Plug-ins/
mkdir -p $plugins_dir

# Copy the IDE Plugin to the plug-ins directory
cp -r Plug-ins/Nim.ideplugin $plugins_dir

#Get the selected Xcode.app's path
xcode_path=$(xcode-select -p)
xcode_path=$(dirname $xcode_path)

# Get Specifications directory
spec_dir="${xcode_path}/SharedFrameworks/SourceModel.framework/Versions/A/Resources/LanguageSpecifications"

# Copy the language specification to the specs directory
cp Specifications/Nim.xclangspec $spec_dir
#cp Specifications/Nim.xcspec $spec_dir

# Get language metadata directory
metadata_dir="${xcode_path}/SharedFrameworks/SourceModel.framework/Versions/A/Resources/LanguageMetadata"

# Copy the source code language plist to the metadata directory
cp Xcode.SourceCodeLanguage.Nim.plist $metadata_dir

# defaults read ${xcode_path}/Info DVTPlugInCompatibilityUUID

echo "Please restart Xcode"
