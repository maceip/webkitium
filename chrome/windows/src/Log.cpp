#include "pch.h"
#include "Log.h"

#include <atomic>
#include <cwchar>
#include <mutex>
#include <string>

namespace webkitium::log {
namespace {

std::mutex g_mu;
HANDLE g_file = INVALID_HANDLE_VALUE;
std::atomic<bool> g_opened{false};
std::wstring g_log_path;

std::wstring ExeDir() {
    wchar_t buf[MAX_PATH] = L"";
    DWORD n = GetModuleFileNameW(nullptr, buf, MAX_PATH);
    if (n == 0 || n == MAX_PATH) return {};
    std::wstring s{ buf, n };
    auto slash = s.find_last_of(L"\\/");
    if (slash == std::wstring::npos) return {};
    return s.substr(0, slash + 1);
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

void WriteUtf8(HANDLE h, std::wstring_view w) {
    // Convert UTF-16 -> UTF-8 for the file; OutputDebugStringW separately
    // takes the UTF-16 directly.
    if (w.empty() || h == INVALID_HANDLE_VALUE) return;
    int need = ::WideCharToMultiByte(
        CP_UTF8, 0, w.data(), static_cast<int>(w.size()),
        nullptr, 0, nullptr, nullptr);
    if (need <= 0) return;
    std::string bytes(static_cast<size_t>(need), '\0');
    ::WideCharToMultiByte(
        CP_UTF8, 0, w.data(), static_cast<int>(w.size()),
        bytes.data(), need, nullptr, nullptr);
    DWORD written = 0;
    ::WriteFile(h, bytes.data(), static_cast<DWORD>(bytes.size()),
                &written, nullptr);
    ::FlushFileBuffers(h);
}

void WriteLineLocked(Level level, std::wstring_view where,
                     std::wstring_view message) {
    SYSTEMTIME st;
    GetLocalTime(&st);
    wchar_t ts[32];
    std::swprintf(ts, sizeof(ts) / sizeof(wchar_t),
                  L"%04u-%02u-%02u %02u:%02u:%02u.%03u",
                  st.wYear, st.wMonth, st.wDay,
                  st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);

    std::wstring line;
    line.reserve(128 + message.size() + where.size());
    line.append(ts).append(L"  ").append(LevelTag(level)).append(L"  ");
    line.append(where.data(), where.size()).append(L"  ");
    line.append(message.data(), message.size()).append(L"\r\n");

    OutputDebugStringW(line.c_str());
    WriteUtf8(g_file, line);
}

}  // namespace

void Initialize() {
    bool expected = false;
    if (!g_opened.compare_exchange_strong(expected, true)) return;

    OutputDebugStringW(L"[webkitium] Log::Initialize entered\r\n");

    // Log alongside the .exe -- guaranteed writable, no env vars involved.
    std::wstring dir = ExeDir();
    if (dir.empty()) {
        OutputDebugStringW(L"[webkitium] Log: ExeDir() empty; logging disabled\r\n");
        return;
    }
    g_log_path = dir + L"webkitium.log";

    {
        std::wstring line = L"[webkitium] Log: opening ";
        line += g_log_path;
        line += L"\r\n";
        OutputDebugStringW(line.c_str());
    }

    g_file = ::CreateFileW(
        g_log_path.c_str(),
        GENERIC_WRITE,
        FILE_SHARE_READ,          // let other processes tail it
        nullptr,
        CREATE_ALWAYS,            // truncate on each launch
        FILE_ATTRIBUTE_NORMAL,
        nullptr);
    if (g_file == INVALID_HANDLE_VALUE) {
        DWORD err = ::GetLastError();
        wchar_t msg[128];
        std::swprintf(msg, 128,
                      L"[webkitium] Log: CreateFileW failed GLE=%lu\r\n", err);
        OutputDebugStringW(msg);
        return;
    }

    WriteLineLocked(Level::Info, L"Log.cpp:Initialize",
                    std::wstring(L"log opened: ") + g_log_path);
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
