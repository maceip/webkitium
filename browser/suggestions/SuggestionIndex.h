// C++ class behind SuggestionsBridgeC. SQLite FTS5-backed unified
// profile store: URL-bar autocomplete + history + bookmarks + reading
// list + open tabs + downloads + tab groups. Owned 1:1 by a
// WkSuggestionsIndex* handle.
//
// Schema (extended):
//   urls               (id, url UNIQUE, title, visit_count,
//                       last_visited_ms, is_bookmarked,
//                       is_in_reading_list)
//   urls_fts           FTS5 mirror of urls.{title, url}
//   bookmark_folders   (id, parent_id, name, symbol, sort_index)
//   bookmark_entries   (id, folder_id, url_id, sort_index)
//   open_tabs          (window_id, sort_index, url_id, group_id,
//                       is_pinned, is_active)
//   tab_groups         (id, name, color_hex, sort_index)
//   downloads          (id, filename, source_url, dest_path,
//                       bytes_total, bytes_received, started_ms,
//                       completed_ms NULLABLE)
//
// Ranking (Chromium-inspired): bm25 + frecency + bookmark boost,
// computed in a single SQL statement so the UI does no re-ranking.

#ifndef WEBKITIUM_SUGGESTIONS_INDEX_H_
#define WEBKITIUM_SUGGESTIONS_INDEX_H_

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

struct sqlite3;
struct sqlite3_stmt;

namespace webkitium::suggestions {

enum class Kind : int32_t {
    TopHit   = 0,
    History  = 1,
    Bookmark = 2,
    Search   = 3,
    Site     = 4,
};

struct Row {
    Kind        kind;
    std::string title;
    std::string subtitle;
    std::string icon_hint;
    double      score;
    int64_t     last_visited_ms = 0;
    int64_t     rowid = 0;
};

struct BookmarkFolder {
    int64_t     id;
    int64_t     parent_id;   // 0 = root
    std::string name;
    std::string symbol;
    int32_t     sort_index;
};

struct BookmarkEntry {
    int64_t     id;
    int64_t     folder_id;
    std::string url;
    std::string title;
};

struct TabGroup {
    int64_t     id;
    std::string name;
    uint32_t    color_argb;
    int32_t     sort_index;
};

struct OpenTab {
    int64_t     window_id;
    int32_t     sort_index;
    std::string url;
    std::string title;
    int64_t     group_id;    // 0 = none
    bool        is_pinned;
    bool        is_active;
};

struct Download {
    int64_t     id;
    std::string filename;
    std::string source_url;
    std::string dest_path;
    int64_t     bytes_total;
    int64_t     bytes_received;
    int64_t     started_ms;
    int64_t     completed_ms;  // 0 = in-flight
};

class Index {
public:
    explicit Index(const std::string& db_path);
    ~Index();

    Index(const Index&)            = delete;
    Index& operator=(const Index&) = delete;

    bool is_open() const { return db_ != nullptr; }

    // History / URL bar
    void record_visit(const std::string& title, const std::string& url);
    void set_bookmarked(const std::string& url, bool is_bookmarked);
    void set_in_reading_list(const std::string& url, bool in_list);
    std::vector<Row> query(const std::string& q, std::size_t limit);
    std::vector<Row> recent_history(const std::string& q, std::size_t limit);
    std::vector<Row> reading_list(std::size_t limit);
    std::vector<Row> bookmarks_flat(std::size_t limit);
    void clear();

    // Bookmark folders + entries
    std::vector<BookmarkFolder> bookmark_folders();
    std::vector<BookmarkEntry>  bookmarks_in(int64_t folder_id);
    int64_t add_bookmark_folder(int64_t parent_id,
                                 const std::string& name,
                                 const std::string& symbol);
    int64_t add_bookmark_entry(int64_t folder_id,
                                const std::string& url,
                                const std::string& title);
    void remove_bookmark_entry(int64_t entry_id);

    // Tab groups
    std::vector<TabGroup> tab_groups();
    int64_t add_tab_group(const std::string& name, uint32_t color_argb);
    void remove_tab_group(int64_t group_id);

    // Open tabs (persistence)
    std::vector<OpenTab> open_tabs(int64_t window_id);
    // Replaces all rows for `window_id` atomically. Pass empty vector to
    // drop all tabs for that window.
    void set_open_tabs(int64_t window_id, const std::vector<OpenTab>& tabs);

    // Downloads (persistence + in-flight)
    std::vector<Download> downloads(std::size_t limit);
    int64_t start_download(const std::string& filename,
                            const std::string& source_url,
                            const std::string& dest_path,
                            int64_t bytes_total);
    void update_download_progress(int64_t id, int64_t bytes_received);
    void complete_download(int64_t id);
    void cancel_download(int64_t id);

private:
    void ensure_schema();
    void exec(const char* sql);

    sqlite3*   db_ = nullptr;
    std::mutex m_;
};

}  // namespace webkitium::suggestions

#endif  // WEBKITIUM_SUGGESTIONS_INDEX_H_
