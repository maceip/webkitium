// Manifest V3 JSON -> ng::ExtensionManifest loader.
//
// Independent of any host platform; runs on the portable C++ core so
// every shell that wants to install extensions can call the same code
// (today nobody does -- the manifest path is the missing piece between
// "wired-but-inactive" and "extensions actually load").
//
// The parser is intentionally tolerant: unknown manifest keys are
// ignored (forward-compat) but malformed JSON (truncated, bad escapes,
// trailing garbage) returns an Error.

#pragma once

#include "core/Result.h"
#include "extensions/ExtensionManifest.h"

#include <string>

namespace ng {

// Parse a Manifest V3 manifest.json into an ExtensionManifest.
// `extensionId` is the on-disk extension id (typically the directory
// name) and is not represented in the JSON itself.
Result<ExtensionManifest> loadManifestFromString(const std::string& json,
                                                 const ExtensionId& extensionId);

// Convenience: read the file at `manifestPath` and parse it.  Returns
// an error if the file cannot be read.
Result<ExtensionManifest> loadManifestFromFile(const std::string& manifestPath,
                                               const ExtensionId& extensionId);

} // namespace ng
