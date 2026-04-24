#include "pch.h"
#include "Log.h"

#include <shlobj.h>

#include <atomic>
#include <cstdio>
#include <cwchar>
#include <filesystem>
#include <mutex>
#include <string>

namespace webkitium::log {
namespace {

std::mutex g_mu;
FILE*      g_fp = nullptr;
std::atomic<bool> g_opened{false};
std::wstring g_log_path;

std::wstring LocalAppDataDir() {
    PWSTR raw = nullptr;
    if (SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &raw) == S_OK) {
        std::wstring dir = raw;
        CoTaskMemFree(raw);
        return dir;
    }
    return L"C:\\Users\\Public";  // fallback
}

std::wstring Widen(std::string_view s) {
    return std::wstring(s.begin(), s.end());
}

const wchar_t* LevelTag(Level l) {
    switch (l) {
        case Level::Info:    return L"INFO ";
        case Level::Warning: return L"WARN ";
        case Level::Error:   return L"ERROR";
    }
    return L"?    ";
}

void WriteLineLocked(Level level, std::wstring_view where,
                     std::wstring_view message) {
    // Timestamp prefix YYYY-MM-DD HH:MM:SS.mmm
    SYSTEMTIME st;
    GetLocalTime(&st);
    wchar_t ts[32];
    std::swprintf(ts, sizeof(ts) / sizeof(wchar_t),
                  L"%04u-%02u-%02u %02u:%02u:%02u.%03u",
                  st.wYear, st.wMonth, st.wDay,
                  st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);

    // Assemble full line (stack buffer with heap fallback).
    std::wstring line;
    line.reserve(128 + message.size() + where.size());
    line.append(ts).append(L"  ").append(LevelTag(level)).append(L"  ");
    line.append(where.data(), where.size()).append(L"  ");
    line.append(message.data(), message.size()).append(L"\r\n");

    OutputDebugStringW(line.c_str());

    if (g_fp) {
        std::fputws(line.c_str(), g_fp);
        std::fflush(g_fp);
    }
}

}  // namespace

void Initialize() {
    bool expected = false;
    if (!g_opened.compare_exchange_strong(expected, true)) return;

    try {
        std::filesystem::path dir = LocalAppDataDir();
        dir /= L"Webkitium";
        std::error_code ec;
        std::filesystem::create_directories(dir, ec);

        g_log_path = (dir / L"webkitium.log").wstring();

        // Truncate on each launch -- keeps the file short and fresh.
        _wfopen_s(&g_fp, g_log_path.c_str(), L"w, ccs=UTF-8");
    } catch (...) {
        // Swallow -- logger is best-effort.
        g_fp = nullptr;
    }

    if (g_fp) {
        WriteLineLocked(Level::Info, L"Log.cpp:Initialize",
                        std::wstring(L"log opened: ") + g_log_path);
    }
}

void Write(Level level, std::string_view where, std::wstring_view message) {
    std::lock_guard<std::mutex> lk(g_mu);
    WriteLineLocked(level, Widen(where), message);
}

void Write(Level level, std::string_view where, std::string_view message) {
    Write(level, where, Widen(message));
}

void WriteHr(Level level, std::string_view where, long hr,
             std::wstring_view context) {
    wchar_t buf[256];
    std::swprintf(buf, sizeof(buf) / sizeof(wchar_t),
                  L"HRESULT 0x%08lX -- %.*s", static_cast<unsigned long>(hr),
                  static_cast<int>(context.size()), context.data());
    Write(level, where, std::wstring_view{ buf });
}

}  // namespace webkitium::log
