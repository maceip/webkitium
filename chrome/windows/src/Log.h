// Simple file logger for the Windows shell.
//
// First call to Log::Write() opens (and truncates) a log file at
// %LOCALAPPDATA%\Webkitium\webkitium.log.  Subsequent calls append
// with thread-safety via an internal mutex.  Also mirrors output to
// OutputDebugStringW so the VS Output window picks it up when
// attached.
//
// Design goals: always-on (both Debug and Release), cheap (no heap
// for short messages), never throws (best-effort).  Prefer LOG_INFO
// and LOG_ERROR macros over raw calls.

#pragma once

#include <string_view>

namespace webkitium::log {

enum class Level { Info, Warning, Error };

// Open the log file (idempotent).  Call once from App::App() at the
// very top.  Safe to call again -- no-ops after first call.
void Initialize();

// Write one line.  `where` typically "File:Line" (use LOG_INFO macro).
void Write(Level level, std::string_view where, std::wstring_view message);

// Convenience overload for narrow messages (converts to wide).
void Write(Level level, std::string_view where, std::string_view message);

// Log an HRESULT with a friendly hex string.
void WriteHr(Level level, std::string_view where, long hr,
             std::wstring_view context);

}  // namespace webkitium::log

#define WK_LOG_WHERE_(file, line) file ":" #line
#define WK_LOG_WHERE(file, line)  WK_LOG_WHERE_(file, line)

#define LOG_INFO(msg)  ::webkitium::log::Write(::webkitium::log::Level::Info,  \
                                               WK_LOG_WHERE(__FILE__, __LINE__), (msg))
#define LOG_WARN(msg)  ::webkitium::log::Write(::webkitium::log::Level::Warning,\
                                               WK_LOG_WHERE(__FILE__, __LINE__), (msg))
#define LOG_ERROR(msg) ::webkitium::log::Write(::webkitium::log::Level::Error, \
                                               WK_LOG_WHERE(__FILE__, __LINE__), (msg))
#define LOG_HR(hr, ctx) ::webkitium::log::WriteHr(::webkitium::log::Level::Error, \
                                                  WK_LOG_WHERE(__FILE__, __LINE__), \
                                                  (hr), (ctx))
