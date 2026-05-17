#include "SuggestionIndex.h"

#include <sqlite3.h>

#include <chrono>
#include <cmath>
#include <cstring>

namespace webkitium::suggestions {

namespace {

int64_t now_ms() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(
               system_clock::now().time_since_epoch())
        .count();
}

// FTS5 needs the query escaped — bare user input can contain syntax tokens
// like " or ( that throw a parse error. Wrap each whitespace-separated
// chunk as a quoted prefix term: foo bar  →  "foo"* "bar"*
std::string build_fts_query(const std::string& q) {
    std::string out;
    std::string cur;
    auto flush = [&] {
        if (cur.empty()) return;
        if (!out.empty()) out += ' ';
        out += '"';
        for (char c : cur) {
            if (c == '"') out += "\"\"";
            else          out += c;
        }
        out += "\"*";
        cur.clear();
    };
    for (char c : q) {
        if (std::isspace(static_cast<unsigned char>(c))) flush();
        else cur += c;
    }
    flush();
    return out;
}

int64_t upsert_url_row(sqlite3* db, const std::string& url, const std::string& title) {
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "INSERT INTO urls(url, title) VALUES(?1, ?2) "
        "ON CONFLICT(url) DO UPDATE SET "
        "  title = CASE WHEN length(excluded.title) > 0 "
        "               THEN excluded.title ELSE urls.title END "
        "RETURNING id;";
    int64_t id = 0;
    if (sqlite3_prepare_v2(db, sql, -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(st, 1, url.c_str(),   -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(st, 2, title.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(st) == SQLITE_ROW) id = sqlite3_column_int64(st, 0);
    }
    sqlite3_finalize(st);
    return id;
}

std::string col_str(sqlite3_stmt* st, int i) {
    const unsigned char* p = sqlite3_column_text(st, i);
    return p ? reinterpret_cast<const char*>(p) : "";
}

}  // namespace

Index::Index(const std::string& db_path) {
    const char* path = db_path.empty() ? ":memory:" : db_path.c_str();
    int rc = sqlite3_open_v2(
        path, &db_,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        nullptr);
    if (rc != SQLITE_OK) {
        if (db_) sqlite3_close(db_);
        db_ = nullptr;
        return;
    }
    exec("PRAGMA journal_mode = WAL;");
    exec("PRAGMA synchronous = NORMAL;");
    exec("PRAGMA temp_store = MEMORY;");
    exec("PRAGMA foreign_keys = ON;");
    ensure_schema();
}

Index::~Index() {
    if (db_) sqlite3_close(db_);
}

void Index::exec(const char* sql) {
    if (!db_) return;
    char* err = nullptr;
    sqlite3_exec(db_, sql, nullptr, nullptr, &err);
    if (err) sqlite3_free(err);
}

void Index::ensure_schema() {
    // Schema migrations: each CREATE IF NOT EXISTS lets us roll forward
    // without dropping existing data. Column additions use defensive ALTER
    // wrapped in INSTEAD OF the "if not exists" idiom (SQLite lacks ADD
    // COLUMN IF NOT EXISTS, so we check pragma_table_info).
    exec(R"SQL(
        CREATE TABLE IF NOT EXISTS urls (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            url             TEXT NOT NULL UNIQUE,
            title           TEXT NOT NULL DEFAULT '',
            visit_count     INTEGER NOT NULL DEFAULT 0,
            last_visited_ms INTEGER NOT NULL DEFAULT 0,
            is_bookmarked   INTEGER NOT NULL DEFAULT 0
        );
    )SQL");

    // Add the reading-list column if upgrading from a pre-existing DB.
    auto has_column = [&](const char* tbl, const char* col) -> bool {
        sqlite3_stmt* st = nullptr;
        std::string sql = std::string("PRAGMA table_info(") + tbl + ");";
        if (sqlite3_prepare_v2(db_, sql.c_str(), -1, &st, nullptr) != SQLITE_OK) return false;
        bool found = false;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (col_str(st, 1) == col) { found = true; break; }
        }
        sqlite3_finalize(st);
        return found;
    };
    if (!has_column("urls", "is_in_reading_list")) {
        exec("ALTER TABLE urls ADD COLUMN is_in_reading_list INTEGER NOT NULL DEFAULT 0;");
    }

    exec(R"SQL(
        CREATE INDEX IF NOT EXISTS idx_urls_last_visited
            ON urls(last_visited_ms DESC);
        CREATE INDEX IF NOT EXISTS idx_urls_bookmarked
            ON urls(is_bookmarked) WHERE is_bookmarked = 1;
        CREATE INDEX IF NOT EXISTS idx_urls_reading_list
            ON urls(is_in_reading_list) WHERE is_in_reading_list = 1;

        CREATE VIRTUAL TABLE IF NOT EXISTS urls_fts USING fts5(
            title, url,
            content='urls', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );

        CREATE TRIGGER IF NOT EXISTS urls_ai AFTER INSERT ON urls BEGIN
            INSERT INTO urls_fts(rowid, title, url)
                VALUES (new.id, new.title, new.url);
        END;
        CREATE TRIGGER IF NOT EXISTS urls_ad AFTER DELETE ON urls BEGIN
            INSERT INTO urls_fts(urls_fts, rowid, title, url)
                VALUES ('delete', old.id, old.title, old.url);
        END;
        CREATE TRIGGER IF NOT EXISTS urls_au AFTER UPDATE ON urls BEGIN
            INSERT INTO urls_fts(urls_fts, rowid, title, url)
                VALUES ('delete', old.id, old.title, old.url);
            INSERT INTO urls_fts(rowid, title, url)
                VALUES (new.id, new.title, new.url);
        END;

        CREATE TABLE IF NOT EXISTS bookmark_folders (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            parent_id  INTEGER NOT NULL DEFAULT 0,
            name       TEXT NOT NULL,
            symbol     TEXT NOT NULL DEFAULT 'folder',
            sort_index INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS bookmark_entries (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            folder_id  INTEGER NOT NULL,
            url_id     INTEGER NOT NULL,
            sort_index INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (folder_id) REFERENCES bookmark_folders(id) ON DELETE CASCADE,
            FOREIGN KEY (url_id)    REFERENCES urls(id)              ON DELETE CASCADE,
            UNIQUE(folder_id, url_id)
        );
        CREATE INDEX IF NOT EXISTS idx_bm_folder ON bookmark_entries(folder_id);

        CREATE TABLE IF NOT EXISTS tab_groups (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            color_argb INTEGER NOT NULL,
            sort_index INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS open_tabs (
            window_id  INTEGER NOT NULL,
            sort_index INTEGER NOT NULL,
            url_id     INTEGER NOT NULL,
            group_id   INTEGER NOT NULL DEFAULT 0,
            is_pinned  INTEGER NOT NULL DEFAULT 0,
            is_active  INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (window_id, sort_index),
            FOREIGN KEY (url_id) REFERENCES urls(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS downloads (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            filename        TEXT NOT NULL,
            source_url      TEXT NOT NULL,
            dest_path       TEXT NOT NULL,
            bytes_total     INTEGER NOT NULL DEFAULT 0,
            bytes_received  INTEGER NOT NULL DEFAULT 0,
            started_ms      INTEGER NOT NULL,
            completed_ms    INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_downloads_started ON downloads(started_ms DESC);
    )SQL");
}

void Index::record_visit(const std::string& title, const std::string& url) {
    if (!db_ || url.empty()) return;
    std::lock_guard<std::mutex> lk(m_);

    sqlite3_stmt* st = nullptr;
    const char* sql =
        "INSERT INTO urls(url, title, visit_count, last_visited_ms) "
        "VALUES(?1, ?2, 1, ?3) "
        "ON CONFLICT(url) DO UPDATE SET "
        "  visit_count = visit_count + 1, "
        "  last_visited_ms = ?3, "
        "  title = CASE WHEN length(excluded.title) > 0 "
        "               THEN excluded.title ELSE urls.title END;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return;
    sqlite3_bind_text(st, 1, url.c_str(),   -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 2, title.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 3, now_ms());
    sqlite3_step(st);
    sqlite3_finalize(st);
}

void Index::set_bookmarked(const std::string& url, bool is_bookmarked) {
    if (!db_ || url.empty()) return;
    std::lock_guard<std::mutex> lk(m_);

    sqlite3_stmt* st = nullptr;
    const char* sql =
        "INSERT INTO urls(url, title, is_bookmarked) "
        "VALUES(?1, '', ?2) "
        "ON CONFLICT(url) DO UPDATE SET is_bookmarked = ?2;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return;
    sqlite3_bind_text(st, 1, url.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(st,  2, is_bookmarked ? 1 : 0);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

void Index::set_in_reading_list(const std::string& url, bool in_list) {
    if (!db_ || url.empty()) return;
    std::lock_guard<std::mutex> lk(m_);

    sqlite3_stmt* st = nullptr;
    const char* sql =
        "INSERT INTO urls(url, title, is_in_reading_list) "
        "VALUES(?1, '', ?2) "
        "ON CONFLICT(url) DO UPDATE SET is_in_reading_list = ?2;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return;
    sqlite3_bind_text(st, 1, url.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(st,  2, in_list ? 1 : 0);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

std::vector<Row> Index::query(const std::string& q, std::size_t limit) {
    std::vector<Row> rows;
    if (!db_ || q.empty() || limit == 0) return rows;
    std::lock_guard<std::mutex> lk(m_);

    const std::string fts_q = build_fts_query(q);
    if (fts_q.empty()) return rows;

    sqlite3_stmt* st = nullptr;
    const char* sql = R"SQL(
        WITH ranked AS (
            SELECT u.id, u.url, u.title, u.visit_count, u.last_visited_ms,
                   u.is_bookmarked,
                   -bm25(urls_fts) AS text_score
            FROM urls_fts
            JOIN urls u ON u.id = urls_fts.rowid
            WHERE urls_fts MATCH ?1
            LIMIT 64
        )
        SELECT id, url, title, visit_count, last_visited_ms, is_bookmarked,
               (text_score
                + visit_count * exp(-((?2 - last_visited_ms) / 86400000.0) / 30.0)
                + CASE WHEN is_bookmarked = 1 THEN 500 ELSE 0 END
               ) AS final_score
        FROM ranked
        ORDER BY final_score DESC
        LIMIT ?3;
    )SQL";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return rows;
    sqlite3_bind_text (st, 1, fts_q.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 2, now_ms());
    sqlite3_bind_int64(st, 3, static_cast<int64_t>(limit));

    bool first = true;
    while (sqlite3_step(st) == SQLITE_ROW) {
        Row r;
        r.rowid    = sqlite3_column_int64(st, 0);
        r.subtitle = col_str(st, 1);
        r.title    = col_str(st, 2);
        if (r.title.empty()) r.title = r.subtitle;
        r.last_visited_ms = sqlite3_column_int64(st, 4);
        bool   bm    = sqlite3_column_int   (st, 5) != 0;
        double score = sqlite3_column_double(st, 6);
        r.score = score;
        if (first && score > 100.0) {
            r.kind = Kind::TopHit;
            r.icon_hint = "arrow.right.circle.fill";
        } else if (bm) {
            r.kind = Kind::Bookmark;
            r.icon_hint = "bookmark";
        } else {
            r.kind = Kind::History;
            r.icon_hint = "clock";
        }
        rows.push_back(std::move(r));
        first = false;
    }
    sqlite3_finalize(st);
    return rows;
}

std::vector<Row> Index::recent_history(const std::string& q, std::size_t limit) {
    std::vector<Row> rows;
    if (!db_ || limit == 0) return rows;
    std::lock_guard<std::mutex> lk(m_);

    sqlite3_stmt* st = nullptr;
    if (q.empty()) {
        const char* sql =
            "SELECT id, url, title, last_visited_ms, is_bookmarked "
            "FROM urls WHERE last_visited_ms > 0 "
            "ORDER BY last_visited_ms DESC LIMIT ?1;";
        if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return rows;
        sqlite3_bind_int64(st, 1, static_cast<int64_t>(limit));
    } else {
        const std::string fts_q = build_fts_query(q);
        if (fts_q.empty()) return rows;
        const char* sql = R"SQL(
            SELECT u.id, u.url, u.title, u.last_visited_ms, u.is_bookmarked
            FROM urls_fts JOIN urls u ON u.id = urls_fts.rowid
            WHERE urls_fts MATCH ?1 AND u.last_visited_ms > 0
            ORDER BY u.last_visited_ms DESC LIMIT ?2;
        )SQL";
        if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return rows;
        sqlite3_bind_text (st, 1, fts_q.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(st, 2, static_cast<int64_t>(limit));
    }

    while (sqlite3_step(st) == SQLITE_ROW) {
        Row r;
        r.rowid    = sqlite3_column_int64(st, 0);
        r.subtitle = col_str(st, 1);
        r.title    = col_str(st, 2);
        if (r.title.empty()) r.title = r.subtitle;
        r.last_visited_ms = sqlite3_column_int64(st, 3);
        bool bm = sqlite3_column_int(st, 4) != 0;
        r.kind = bm ? Kind::Bookmark : Kind::History;
        r.icon_hint = bm ? "bookmark" : "clock";
        rows.push_back(std::move(r));
    }
    sqlite3_finalize(st);
    return rows;
}

std::vector<Row> Index::reading_list(std::size_t limit) {
    std::vector<Row> rows;
    if (!db_ || limit == 0) return rows;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "SELECT id, url, title, last_visited_ms FROM urls "
        "WHERE is_in_reading_list = 1 "
        "ORDER BY last_visited_ms DESC LIMIT ?1;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return rows;
    sqlite3_bind_int64(st, 1, static_cast<int64_t>(limit));
    while (sqlite3_step(st) == SQLITE_ROW) {
        Row r;
        r.rowid    = sqlite3_column_int64(st, 0);
        r.subtitle = col_str(st, 1);
        r.title    = col_str(st, 2);
        if (r.title.empty()) r.title = r.subtitle;
        r.last_visited_ms = sqlite3_column_int64(st, 3);
        r.kind = Kind::Bookmark;        // share the Bookmark UI section
        r.icon_hint = "eyeglasses";
        rows.push_back(std::move(r));
    }
    sqlite3_finalize(st);
    return rows;
}

std::vector<Row> Index::bookmarks_flat(std::size_t limit) {
    std::vector<Row> rows;
    if (!db_ || limit == 0) return rows;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "SELECT id, url, title, last_visited_ms FROM urls "
        "WHERE is_bookmarked = 1 "
        "ORDER BY last_visited_ms DESC LIMIT ?1;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return rows;
    sqlite3_bind_int64(st, 1, static_cast<int64_t>(limit));
    while (sqlite3_step(st) == SQLITE_ROW) {
        Row r;
        r.rowid    = sqlite3_column_int64(st, 0);
        r.subtitle = col_str(st, 1);
        r.title    = col_str(st, 2);
        if (r.title.empty()) r.title = r.subtitle;
        r.last_visited_ms = sqlite3_column_int64(st, 3);
        r.kind = Kind::Bookmark;
        r.icon_hint = "bookmark";
        rows.push_back(std::move(r));
    }
    sqlite3_finalize(st);
    return rows;
}

void Index::clear() {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    exec("DELETE FROM urls;"
         "DELETE FROM bookmark_entries;"
         "DELETE FROM bookmark_folders;"
         "DELETE FROM open_tabs;"
         "DELETE FROM tab_groups;"
         "DELETE FROM downloads;");
}

// ---------- Bookmark folders + entries ----------

std::vector<BookmarkFolder> Index::bookmark_folders() {
    std::vector<BookmarkFolder> out;
    if (!db_) return out;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db_,
        "SELECT id, parent_id, name, symbol, sort_index FROM bookmark_folders "
        "ORDER BY parent_id, sort_index, id;", -1, &st, nullptr) != SQLITE_OK) return out;
    while (sqlite3_step(st) == SQLITE_ROW) {
        BookmarkFolder f;
        f.id         = sqlite3_column_int64(st, 0);
        f.parent_id  = sqlite3_column_int64(st, 1);
        f.name       = col_str(st, 2);
        f.symbol     = col_str(st, 3);
        f.sort_index = sqlite3_column_int(st, 4);
        out.push_back(std::move(f));
    }
    sqlite3_finalize(st);
    return out;
}

std::vector<BookmarkEntry> Index::bookmarks_in(int64_t folder_id) {
    std::vector<BookmarkEntry> out;
    if (!db_) return out;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "SELECT b.id, b.folder_id, u.url, u.title "
        "FROM bookmark_entries b JOIN urls u ON u.id = b.url_id "
        "WHERE b.folder_id = ?1 "
        "ORDER BY b.sort_index, b.id;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return out;
    sqlite3_bind_int64(st, 1, folder_id);
    while (sqlite3_step(st) == SQLITE_ROW) {
        BookmarkEntry e;
        e.id        = sqlite3_column_int64(st, 0);
        e.folder_id = sqlite3_column_int64(st, 1);
        e.url       = col_str(st, 2);
        e.title     = col_str(st, 3);
        out.push_back(std::move(e));
    }
    sqlite3_finalize(st);
    return out;
}

int64_t Index::add_bookmark_folder(int64_t parent_id,
                                    const std::string& name,
                                    const std::string& symbol) {
    if (!db_) return 0;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db_,
        "INSERT INTO bookmark_folders(parent_id, name, symbol) "
        "VALUES(?1, ?2, ?3) RETURNING id;", -1, &st, nullptr) != SQLITE_OK) return 0;
    sqlite3_bind_int64(st, 1, parent_id);
    sqlite3_bind_text (st, 2, name  .c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text (st, 3, symbol.c_str(), -1, SQLITE_TRANSIENT);
    int64_t id = 0;
    if (sqlite3_step(st) == SQLITE_ROW) id = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    return id;
}

int64_t Index::add_bookmark_entry(int64_t folder_id,
                                   const std::string& url,
                                   const std::string& title) {
    if (!db_ || url.empty()) return 0;
    std::lock_guard<std::mutex> lk(m_);
    int64_t url_id = upsert_url_row(db_, url, title);
    if (!url_id) return 0;
    // Also flip is_bookmarked so the URL ranks higher.
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_, "UPDATE urls SET is_bookmarked = 1 WHERE id = ?1;",
                       -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, url_id);
    sqlite3_step(st);
    sqlite3_finalize(st);
    // Insert/ignore the bookmark_entries row.
    sqlite3_prepare_v2(db_,
        "INSERT OR IGNORE INTO bookmark_entries(folder_id, url_id) "
        "VALUES(?1, ?2) RETURNING id;", -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, folder_id);
    sqlite3_bind_int64(st, 2, url_id);
    int64_t id = 0;
    if (sqlite3_step(st) == SQLITE_ROW) id = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    return id;
}

void Index::remove_bookmark_entry(int64_t entry_id) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "DELETE FROM bookmark_entries WHERE id = ?1;", -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, entry_id);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

// ---------- Tab groups ----------

std::vector<TabGroup> Index::tab_groups() {
    std::vector<TabGroup> out;
    if (!db_) return out;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db_,
        "SELECT id, name, color_argb, sort_index FROM tab_groups "
        "ORDER BY sort_index, id;", -1, &st, nullptr) != SQLITE_OK) return out;
    while (sqlite3_step(st) == SQLITE_ROW) {
        TabGroup g;
        g.id         = sqlite3_column_int64(st, 0);
        g.name       = col_str(st, 1);
        g.color_argb = static_cast<uint32_t>(sqlite3_column_int64(st, 2));
        g.sort_index = sqlite3_column_int(st, 3);
        out.push_back(std::move(g));
    }
    sqlite3_finalize(st);
    return out;
}

int64_t Index::add_tab_group(const std::string& name, uint32_t color_argb) {
    if (!db_) return 0;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "INSERT INTO tab_groups(name, color_argb) VALUES(?1, ?2) "
        "RETURNING id;", -1, &st, nullptr);
    sqlite3_bind_text (st, 1, name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 2, static_cast<int64_t>(color_argb));
    int64_t id = 0;
    if (sqlite3_step(st) == SQLITE_ROW) id = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    return id;
}

void Index::remove_tab_group(int64_t group_id) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "UPDATE open_tabs SET group_id = 0 WHERE group_id = ?1;",
        -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, group_id);
    sqlite3_step(st);
    sqlite3_finalize(st);
    sqlite3_prepare_v2(db_, "DELETE FROM tab_groups WHERE id = ?1;",
                       -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, group_id);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

// ---------- Open tabs persistence ----------

std::vector<OpenTab> Index::open_tabs(int64_t window_id) {
    std::vector<OpenTab> out;
    if (!db_) return out;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "SELECT t.window_id, t.sort_index, u.url, u.title, "
        "       t.group_id, t.is_pinned, t.is_active "
        "FROM open_tabs t JOIN urls u ON u.id = t.url_id "
        "WHERE t.window_id = ?1 ORDER BY t.sort_index;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return out;
    sqlite3_bind_int64(st, 1, window_id);
    while (sqlite3_step(st) == SQLITE_ROW) {
        OpenTab t;
        t.window_id  = sqlite3_column_int64(st, 0);
        t.sort_index = sqlite3_column_int  (st, 1);
        t.url        = col_str(st, 2);
        t.title      = col_str(st, 3);
        t.group_id   = sqlite3_column_int64(st, 4);
        t.is_pinned  = sqlite3_column_int(st, 5) != 0;
        t.is_active  = sqlite3_column_int(st, 6) != 0;
        out.push_back(std::move(t));
    }
    sqlite3_finalize(st);
    return out;
}

void Index::set_open_tabs(int64_t window_id, const std::vector<OpenTab>& tabs) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    exec("BEGIN IMMEDIATE;");
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "DELETE FROM open_tabs WHERE window_id = ?1;", -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, window_id);
    sqlite3_step(st);
    sqlite3_finalize(st);

    for (const auto& t : tabs) {
        int64_t url_id = upsert_url_row(db_, t.url, t.title);
        if (!url_id) continue;
        sqlite3_prepare_v2(db_,
            "INSERT INTO open_tabs(window_id, sort_index, url_id, "
            "group_id, is_pinned, is_active) "
            "VALUES(?1, ?2, ?3, ?4, ?5, ?6);", -1, &st, nullptr);
        sqlite3_bind_int64(st, 1, t.window_id);
        sqlite3_bind_int  (st, 2, t.sort_index);
        sqlite3_bind_int64(st, 3, url_id);
        sqlite3_bind_int64(st, 4, t.group_id);
        sqlite3_bind_int  (st, 5, t.is_pinned ? 1 : 0);
        sqlite3_bind_int  (st, 6, t.is_active ? 1 : 0);
        sqlite3_step(st);
        sqlite3_finalize(st);
    }
    exec("COMMIT;");
}

// ---------- Downloads ----------

std::vector<Download> Index::downloads(std::size_t limit) {
    std::vector<Download> out;
    if (!db_) return out;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    const char* sql =
        "SELECT id, filename, source_url, dest_path, "
        "       bytes_total, bytes_received, started_ms, completed_ms "
        "FROM downloads ORDER BY started_ms DESC LIMIT ?1;";
    if (sqlite3_prepare_v2(db_, sql, -1, &st, nullptr) != SQLITE_OK) return out;
    sqlite3_bind_int64(st, 1, static_cast<int64_t>(limit));
    while (sqlite3_step(st) == SQLITE_ROW) {
        Download d;
        d.id             = sqlite3_column_int64(st, 0);
        d.filename       = col_str(st, 1);
        d.source_url     = col_str(st, 2);
        d.dest_path      = col_str(st, 3);
        d.bytes_total    = sqlite3_column_int64(st, 4);
        d.bytes_received = sqlite3_column_int64(st, 5);
        d.started_ms     = sqlite3_column_int64(st, 6);
        d.completed_ms   = sqlite3_column_int64(st, 7);
        out.push_back(std::move(d));
    }
    sqlite3_finalize(st);
    return out;
}

int64_t Index::start_download(const std::string& filename,
                               const std::string& source_url,
                               const std::string& dest_path,
                               int64_t bytes_total) {
    if (!db_) return 0;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "INSERT INTO downloads(filename, source_url, dest_path, "
        "bytes_total, started_ms) VALUES(?1, ?2, ?3, ?4, ?5) "
        "RETURNING id;", -1, &st, nullptr);
    sqlite3_bind_text (st, 1, filename  .c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text (st, 2, source_url.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text (st, 3, dest_path .c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 4, bytes_total);
    sqlite3_bind_int64(st, 5, now_ms());
    int64_t id = 0;
    if (sqlite3_step(st) == SQLITE_ROW) id = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    return id;
}

void Index::update_download_progress(int64_t id, int64_t bytes_received) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "UPDATE downloads SET bytes_received = ?2 WHERE id = ?1;",
        -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, id);
    sqlite3_bind_int64(st, 2, bytes_received);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

void Index::complete_download(int64_t id) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "UPDATE downloads SET completed_ms = ?2, "
        "bytes_received = MAX(bytes_received, bytes_total) "
        "WHERE id = ?1;", -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, id);
    sqlite3_bind_int64(st, 2, now_ms());
    sqlite3_step(st);
    sqlite3_finalize(st);
}

void Index::cancel_download(int64_t id) {
    if (!db_) return;
    std::lock_guard<std::mutex> lk(m_);
    sqlite3_stmt* st = nullptr;
    sqlite3_prepare_v2(db_,
        "DELETE FROM downloads WHERE id = ?1;", -1, &st, nullptr);
    sqlite3_bind_int64(st, 1, id);
    sqlite3_step(st);
    sqlite3_finalize(st);
}

}  // namespace webkitium::suggestions
