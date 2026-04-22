// JSON writer for --probe mode. The shape matches the Windows runner's
// validation-report.json expectation (see webgpu-dawn-runbook.md
// § Runtime Probe Acceptance), extended with the surface/render block we
// intend to add when GPUCanvasContext::create lands on Windows.

#include "webgpu_host/Host.h"

#include <cstdio>
#include <string>

namespace webgpu_host {

namespace {

void appendEscaped(std::string& out, std::string_view v) {
    out.push_back('"');
    for (char c : v) {
        switch (c) {
        case '"':  out.append("\\\""); break;
        case '\\': out.append("\\\\"); break;
        case '\n': out.append("\\n");  break;
        case '\r': out.append("\\r");  break;
        case '\t': out.append("\\t");  break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buf[8];
                std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                out.append(buf);
            } else {
                out.push_back(c);
            }
        }
    }
    out.push_back('"');
}

void appendPair(std::string& out, std::string_view key, std::string_view value, bool comma) {
    appendEscaped(out, key);
    out.append(": ");
    appendEscaped(out, value);
    if (comma) out.append(",\n    ");
}

void appendPairBool(std::string& out, std::string_view key, bool value, bool comma) {
    appendEscaped(out, key);
    out.append(": ");
    out.append(value ? "true" : "false");
    if (comma) out.append(",\n    ");
}

void appendPairUint(std::string& out, std::string_view key, uint32_t value, bool comma) {
    appendEscaped(out, key);
    out.append(": ");
    out.append(std::to_string(value));
    if (comma) out.append(",\n    ");
}

} // namespace

bool writeProbeReport(const std::string& path, const ProbeReport& r, std::string& err) {
    std::string s;
    s.reserve(1024);

    s.append("{\n");
    s.append("  \"runtime\": {\n    ");
    appendPairBool(s, "gpuAvailable", r.gpuAvailable, true);
    appendPairBool(s, "queueAvailable", r.queueAvailable, true);

    s.append("\"adapter\": {\n      ");
    appendPair(s, "backend", r.adapterBackend, true);
    appendPair(s, "vendor",  r.adapterVendor,  true);
    appendPair(s, "device",  r.adapterDevice,  false);
    s.append("\n    },\n    ");

    s.append("\"surface\": {\n      ");
    appendPairBool(s, "configured", r.surfaceConfigured, true);
    appendPair(s, "format", r.surfaceFormat, false);
    s.append("\n    },\n    ");

    s.append("\"render\": {\n      ");
    appendPairUint(s, "framesSubmitted", r.framesSubmitted, true);
    appendPairUint(s, "framesPresented", r.framesPresented, true);
    if (r.lastError.empty()) {
        s.append("\"lastError\": null\n    ");
    } else {
        appendPair(s, "lastError", r.lastError, false);
        s.push_back('\n');
        s.append("    ");
    }
    s.append("}");

    if (!r.suitesJson.empty()) {
        s.append(",\n    \"probes\": ");
        s.append(r.suitesJson);
        s.append(",\n    ");
        appendPairBool(s, "probesOk", r.suitesAllOk, false);
    }

    s.append("\n  }\n");
    s.append("}\n");

    if (path.empty()) {
        std::fwrite(s.data(), 1, s.size(), stdout);
        std::fflush(stdout);
        return true;
    }

    FILE* f = nullptr;
    if (fopen_s(&f, path.c_str(), "wb") != 0 || !f) {
        err = "failed to open probe JSON for write: " + path;
        return false;
    }
    bool ok = std::fwrite(s.data(), 1, s.size(), f) == s.size();
    std::fclose(f);
    if (!ok) err = "short write to " + path;
    return ok;
}

} // namespace webgpu_host
