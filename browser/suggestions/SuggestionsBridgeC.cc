#include "SuggestionsBridgeC.h"

#include "SuggestionIndex.h"

#include <cstring>
#include <new>
#include <string>
#include <vector>

using webkitium::suggestions::Index;
using webkitium::suggestions::Kind;
using webkitium::suggestions::Row;
using webkitium::suggestions::BookmarkFolder;
using webkitium::suggestions::BookmarkEntry;
using webkitium::suggestions::TabGroup;
using webkitium::suggestions::OpenTab;
using webkitium::suggestions::Download;

namespace {

struct ResultsHolder {
    std::vector<WkSuggestionRow>  rows;
    std::vector<std::string>      titles;
    std::vector<std::string>      subtitles;
    std::vector<std::string>      icons;
};

struct BookmarkFolderHolder {
    std::vector<WkBookmarkFolder> folders;
    std::vector<std::string>      names;
    std::vector<std::string>      symbols;
};

struct BookmarkEntryHolder {
    std::vector<WkBookmarkEntry> entries;
    std::vector<std::string>     urls;
    std::vector<std::string>     titles;
};

struct TabGroupHolder {
    std::vector<WkTabGroup>   groups;
    std::vector<std::string>  names;
};

struct OpenTabHolder {
    std::vector<WkOpenTab>    tabs;
    std::vector<std::string>  urls;
    std::vector<std::string>  titles;
};

struct DownloadHolder {
    std::vector<WkDownload>   downloads;
    std::vector<std::string>  filenames;
    std::vector<std::string>  source_urls;
    std::vector<std::string>  dest_paths;
};

void fill_results(std::vector<Row>&& rows, WkSuggestionResults* out) {
    auto* h = new ResultsHolder;
    h->rows.reserve(rows.size());
    h->titles.reserve(rows.size());
    h->subtitles.reserve(rows.size());
    h->icons.reserve(rows.size());
    for (auto& r : rows) {
        h->titles.push_back(std::move(r.title));
        h->subtitles.push_back(std::move(r.subtitle));
        h->icons.push_back(std::move(r.icon_hint));
        WkSuggestionRow brow{};
        brow.kind             = static_cast<WkSuggestionKind>(r.kind);
        brow.title            = h->titles.back().c_str();
        brow.subtitle         = h->subtitles.back().c_str();
        brow.icon_hint        = h->icons.back().c_str();
        brow.score            = r.score;
        brow.last_visited_ms  = r.last_visited_ms;
        h->rows.push_back(brow);
    }
    out->rows    = h->rows.empty() ? nullptr : h->rows.data();
    out->count   = h->rows.size();
    out->_opaque = h;
}

}  // namespace

extern "C" {

// ---------- Lifecycle ----------

WkSuggestionsIndex* wk_suggestions_open(const char* db_path) {
    auto idx = new (std::nothrow) Index(db_path ? db_path : "");
    if (!idx) return nullptr;
    if (!idx->is_open()) { delete idx; return nullptr; }
    return reinterpret_cast<WkSuggestionsIndex*>(idx);
}
void wk_suggestions_close(WkSuggestionsIndex* index) {
    delete reinterpret_cast<Index*>(index);
}
void wk_suggestions_clear(WkSuggestionsIndex* index) {
    if (index) reinterpret_cast<Index*>(index)->clear();
}

// ---------- URL bar / history ----------

void wk_suggestions_record_visit(WkSuggestionsIndex* index,
                                  const char* title, const char* url) {
    if (!index || !url) return;
    reinterpret_cast<Index*>(index)->record_visit(title ? title : "", url);
}
void wk_suggestions_set_bookmarked(WkSuggestionsIndex* index,
                                    const char* url, int is_bookmarked) {
    if (!index || !url) return;
    reinterpret_cast<Index*>(index)->set_bookmarked(url, is_bookmarked != 0);
}
void wk_suggestions_set_in_reading_list(WkSuggestionsIndex* index,
                                         const char* url, int in_list) {
    if (!index || !url) return;
    reinterpret_cast<Index*>(index)->set_in_reading_list(url, in_list != 0);
}

int wk_suggestions_query(WkSuggestionsIndex* index,
                          const char* query, size_t limit,
                          WkSuggestionResults* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index || !query) return 0;
    fill_results(reinterpret_cast<Index*>(index)->query(query, limit), out);
    return 1;
}
int wk_suggestions_recent_history(WkSuggestionsIndex* index,
                                   const char* query, size_t limit,
                                   WkSuggestionResults* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    fill_results(reinterpret_cast<Index*>(index)->recent_history(
                     query ? query : "", limit), out);
    return 1;
}
int wk_suggestions_reading_list(WkSuggestionsIndex* index, size_t limit,
                                 WkSuggestionResults* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    fill_results(reinterpret_cast<Index*>(index)->reading_list(limit), out);
    return 1;
}
int wk_suggestions_bookmarks_flat(WkSuggestionsIndex* index, size_t limit,
                                   WkSuggestionResults* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    fill_results(reinterpret_cast<Index*>(index)->bookmarks_flat(limit), out);
    return 1;
}
void wk_suggestions_release_results(WkSuggestionResults* results) {
    if (!results) return;
    delete static_cast<ResultsHolder*>(results->_opaque);
    std::memset(results, 0, sizeof(*results));
}

// ---------- Bookmark folders + entries ----------

int wk_bookmarks_folders(WkSuggestionsIndex* index, WkBookmarkFolderList* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    auto rows = reinterpret_cast<Index*>(index)->bookmark_folders();
    auto* h = new BookmarkFolderHolder;
    h->folders.reserve(rows.size());
    h->names  .reserve(rows.size());
    h->symbols.reserve(rows.size());
    for (auto& f : rows) {
        h->names  .push_back(std::move(f.name));
        h->symbols.push_back(std::move(f.symbol));
        WkBookmarkFolder bf{};
        bf.id         = f.id;
        bf.parent_id  = f.parent_id;
        bf.name       = h->names.back().c_str();
        bf.symbol     = h->symbols.back().c_str();
        bf.sort_index = f.sort_index;
        h->folders.push_back(bf);
    }
    out->folders = h->folders.empty() ? nullptr : h->folders.data();
    out->count   = h->folders.size();
    out->_opaque = h;
    return 1;
}
int wk_bookmarks_in(WkSuggestionsIndex* index, int64_t folder_id,
                     WkBookmarkEntryList* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    auto rows = reinterpret_cast<Index*>(index)->bookmarks_in(folder_id);
    auto* h = new BookmarkEntryHolder;
    h->entries.reserve(rows.size());
    h->urls   .reserve(rows.size());
    h->titles .reserve(rows.size());
    for (auto& e : rows) {
        h->urls   .push_back(std::move(e.url));
        h->titles .push_back(std::move(e.title));
        WkBookmarkEntry be{};
        be.id        = e.id;
        be.folder_id = e.folder_id;
        be.url       = h->urls.back().c_str();
        be.title     = h->titles.back().c_str();
        h->entries.push_back(be);
    }
    out->entries = h->entries.empty() ? nullptr : h->entries.data();
    out->count   = h->entries.size();
    out->_opaque = h;
    return 1;
}
int64_t wk_bookmarks_add_folder(WkSuggestionsIndex* index, int64_t parent_id,
                                 const char* name, const char* symbol) {
    if (!index || !name) return 0;
    return reinterpret_cast<Index*>(index)->add_bookmark_folder(
        parent_id, name, symbol ? symbol : "folder");
}
int64_t wk_bookmarks_add_entry(WkSuggestionsIndex* index, int64_t folder_id,
                                const char* url, const char* title) {
    if (!index || !url) return 0;
    return reinterpret_cast<Index*>(index)->add_bookmark_entry(
        folder_id, url, title ? title : "");
}
void wk_bookmarks_remove_entry(WkSuggestionsIndex* index, int64_t entry_id) {
    if (!index) return;
    reinterpret_cast<Index*>(index)->remove_bookmark_entry(entry_id);
}
void wk_bookmarks_release_folders(WkBookmarkFolderList* list) {
    if (!list) return;
    delete static_cast<BookmarkFolderHolder*>(list->_opaque);
    std::memset(list, 0, sizeof(*list));
}
void wk_bookmarks_release_entries(WkBookmarkEntryList* list) {
    if (!list) return;
    delete static_cast<BookmarkEntryHolder*>(list->_opaque);
    std::memset(list, 0, sizeof(*list));
}

// ---------- Tab groups ----------

int wk_tab_groups_list(WkSuggestionsIndex* index, WkTabGroupList* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    auto rows = reinterpret_cast<Index*>(index)->tab_groups();
    auto* h = new TabGroupHolder;
    h->groups.reserve(rows.size());
    h->names .reserve(rows.size());
    for (auto& g : rows) {
        h->names.push_back(std::move(g.name));
        WkTabGroup wg{};
        wg.id         = g.id;
        wg.name       = h->names.back().c_str();
        wg.color_argb = g.color_argb;
        wg.sort_index = g.sort_index;
        h->groups.push_back(wg);
    }
    out->groups  = h->groups.empty() ? nullptr : h->groups.data();
    out->count   = h->groups.size();
    out->_opaque = h;
    return 1;
}
int64_t wk_tab_groups_add(WkSuggestionsIndex* index, const char* name,
                           uint32_t color_argb) {
    if (!index || !name) return 0;
    return reinterpret_cast<Index*>(index)->add_tab_group(name, color_argb);
}
void wk_tab_groups_remove(WkSuggestionsIndex* index, int64_t group_id) {
    if (!index) return;
    reinterpret_cast<Index*>(index)->remove_tab_group(group_id);
}
void wk_tab_groups_release(WkTabGroupList* list) {
    if (!list) return;
    delete static_cast<TabGroupHolder*>(list->_opaque);
    std::memset(list, 0, sizeof(*list));
}

// ---------- Open tabs persistence ----------

int wk_open_tabs_list(WkSuggestionsIndex* index, int64_t window_id,
                       WkOpenTabList* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    auto rows = reinterpret_cast<Index*>(index)->open_tabs(window_id);
    auto* h = new OpenTabHolder;
    h->tabs  .reserve(rows.size());
    h->urls  .reserve(rows.size());
    h->titles.reserve(rows.size());
    for (auto& t : rows) {
        h->urls  .push_back(std::move(t.url));
        h->titles.push_back(std::move(t.title));
        WkOpenTab wt{};
        wt.window_id  = t.window_id;
        wt.sort_index = t.sort_index;
        wt.url        = h->urls.back().c_str();
        wt.title      = h->titles.back().c_str();
        wt.group_id   = t.group_id;
        wt.is_pinned  = t.is_pinned ? 1 : 0;
        wt.is_active  = t.is_active ? 1 : 0;
        h->tabs.push_back(wt);
    }
    out->tabs    = h->tabs.empty() ? nullptr : h->tabs.data();
    out->count   = h->tabs.size();
    out->_opaque = h;
    return 1;
}
void wk_open_tabs_set(WkSuggestionsIndex* index, int64_t window_id,
                       const WkOpenTab* tabs, size_t count) {
    if (!index) return;
    std::vector<OpenTab> in;
    in.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        OpenTab t;
        t.window_id  = tabs[i].window_id;
        t.sort_index = tabs[i].sort_index;
        t.url        = tabs[i].url   ? tabs[i].url   : "";
        t.title      = tabs[i].title ? tabs[i].title : "";
        t.group_id   = tabs[i].group_id;
        t.is_pinned  = tabs[i].is_pinned != 0;
        t.is_active  = tabs[i].is_active != 0;
        in.push_back(std::move(t));
    }
    reinterpret_cast<Index*>(index)->set_open_tabs(window_id, in);
}
void wk_open_tabs_release(WkOpenTabList* list) {
    if (!list) return;
    delete static_cast<OpenTabHolder*>(list->_opaque);
    std::memset(list, 0, sizeof(*list));
}

// ---------- Downloads ----------

int wk_downloads_list(WkSuggestionsIndex* index, size_t limit,
                       WkDownloadList* out) {
    if (!out) return 0;
    std::memset(out, 0, sizeof(*out));
    if (!index) return 0;
    auto rows = reinterpret_cast<Index*>(index)->downloads(limit);
    auto* h = new DownloadHolder;
    h->downloads .reserve(rows.size());
    h->filenames .reserve(rows.size());
    h->source_urls.reserve(rows.size());
    h->dest_paths .reserve(rows.size());
    for (auto& d : rows) {
        h->filenames  .push_back(std::move(d.filename));
        h->source_urls.push_back(std::move(d.source_url));
        h->dest_paths .push_back(std::move(d.dest_path));
        WkDownload wd{};
        wd.id             = d.id;
        wd.filename       = h->filenames.back().c_str();
        wd.source_url     = h->source_urls.back().c_str();
        wd.dest_path      = h->dest_paths.back().c_str();
        wd.bytes_total    = d.bytes_total;
        wd.bytes_received = d.bytes_received;
        wd.started_ms     = d.started_ms;
        wd.completed_ms   = d.completed_ms;
        h->downloads.push_back(wd);
    }
    out->downloads = h->downloads.empty() ? nullptr : h->downloads.data();
    out->count     = h->downloads.size();
    out->_opaque   = h;
    return 1;
}
int64_t wk_downloads_start(WkSuggestionsIndex* index,
                            const char* filename, const char* source_url,
                            const char* dest_path, int64_t bytes_total) {
    if (!index || !filename || !source_url || !dest_path) return 0;
    return reinterpret_cast<Index*>(index)->start_download(
        filename, source_url, dest_path, bytes_total);
}
void wk_downloads_progress(WkSuggestionsIndex* index, int64_t id,
                            int64_t bytes_received) {
    if (!index) return;
    reinterpret_cast<Index*>(index)->update_download_progress(id, bytes_received);
}
void wk_downloads_complete(WkSuggestionsIndex* index, int64_t id) {
    if (index) reinterpret_cast<Index*>(index)->complete_download(id);
}
void wk_downloads_cancel(WkSuggestionsIndex* index, int64_t id) {
    if (index) reinterpret_cast<Index*>(index)->cancel_download(id);
}
void wk_downloads_release(WkDownloadList* list) {
    if (!list) return;
    delete static_cast<DownloadHolder*>(list->_opaque);
    std::memset(list, 0, sizeof(*list));
}

}  // extern "C"
