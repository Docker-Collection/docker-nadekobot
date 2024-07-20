#!/bin/sh

# Find all .csproj files, add NuGetAudit disable
find . -name "*.csproj" -type f | while read -r file; do
    awk '/<PropertyGroup>/ { print; print "        <NuGetAudit>false</NuGetAudit>"; next }1' "$file" > temp && mv temp "$file"
done
