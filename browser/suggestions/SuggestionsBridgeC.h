// Pure-C ABI wrapper around browser/suggestions/.
//
// Unified profile store: URL-bar autocomplete + history + bookmarks +
// reading list + open-tabs persistence + tab groups + downloads.
// Backed by a single SQLite FTS5 database per profile (in-memory for
// private windows).
//
// Same shape as browser/color/ColorBridgeC.h: no C++ types crossing the
// boundary, no exception propagation, no STL in this header.

#ifndef WEBKITIUM_SUGGESTIONS_BRIDGE_C_H_
#define WEBKITIUM_SUGGESTIONS_BRIDGE_C_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkSuggestionsIndex WkSuggestionsIndex;

typedef enum {
    WK_SUGGESTION_KIND_TOP_HIT     = 0,
    WK_SUGGESTION_KIND_HISTORY     = 1,
    WK_SUGGESTION_KIND_BOOKMARK    = 2,
    WK_SUGGESTION_KIND_SEARCH      = 3,
    WK_SUGGESTION_KIND_SITE        = 4
} WkSuggestionKind;

typedef struct {
    WkSuggestionKind kind;
    const char*      title;
    const char*      subtitle;
    const char*      icon_hint;
    double           score;
    int64_t          last_visited_ms;
} WkSuggestionRow;

typedef struct {
    const WkSuggestionRow* rows;
    size_t                 count;
    void*                  _opaque;
} WkSuggestionResults;

// ---------- Lifecycle ----------

WkSuggestionsIndex* wk_suggestions_open(const char* db_path);
void                wk_suggestions_close(WkSuggestionsIndex* index);
void                wk_suggestions_clear(WkSuggestionsIndex* index);

// ---------- URL bar / history ----------

void wk_suggestions_record_visit(WkSuggestionsIndex* index,
                                  const char* title,
                                  const char* url);
void wk_suggestions_set_bookmarked(WkSuggestionsIndex* index,
                                    const char* url,
                                    int is_bookmarked);
void wk_suggestions_set_in_reading_list(WkSuggestionsIndex* index,
                                         const char* url,
                                         int in_list);

int  wk_suggestions_query(WkSuggestionsIndex* index,
                           const char* query,
                           size_t limit,
                           WkSuggestionResults* out_results);
int  wk_suggestions_recent_history(WkSuggestionsIndex* index,
                                    const char* query,
                                    size_t limit,
                                    WkSuggestionResults* out_results);
int  wk_suggestions_reading_list(WkSuggestionsIndex* index,
                                  size_t limit,
                                  WkSuggestionResults* out_results);
int  wk_suggestions_bookmarks_flat(WkSuggestionsIndex* index,
                                    size_t limit,
                                    WkSuggestionResults* out_results);

void wk_suggestions_release_results(WkSuggestionResults* results);

// ---------- Bookmarks (folders + entries) ----------

typedef struct {
    int64_t     id;
    int64_t     parent_id;
    const char* name;
    const char* symbol;
    int32_t     sort_index;
} WkBookmarkFolder;

typedef struct {
    int64_t     id;
    int64_t     folder_id;
    const char* url;
    const char* title;
} WkBookmarkEntry;

typedef struct {
    const WkBookmarkFolder* folders;
    size_t                  count;
    void*                   _opaque;
} WkBookmarkFolderList;

typedef struct {
    const WkBookmarkEntry* entries;
    size_t                 count;
    void*                  _opaque;
} WkBookmarkEntryList;

int     wk_bookmarks_folders(WkSuggestionsIndex* index,
                              WkBookmarkFolderList* out_folders);
int     wk_bookmarks_in(WkSuggestionsIndex* index,
                         int64_t folder_id,
                         WkBookmarkEntryList* out_entries);
int64_t wk_bookmarks_add_folder(WkSuggestionsIndex* index,
                                 int64_t parent_id,
                                 const char* name,
                                 const char* symbol);
int64_t wk_bookmarks_add_entry(WkSuggestionsIndex* index,
                                int64_t folder_id,
                                const char* url,
                                const char* title);
void    wk_bookmarks_remove_entry(WkSuggestionsIndex* index,
                                   int64_t entry_id);
void    wk_bookmarks_release_folders(WkBookmarkFolderList* list);
void    wk_bookmarks_release_entries(WkBookmarkEntryList* list);

// ---------- Tab groups ----------

typedef struct {
    int64_t     id;
    const char* name;
    uint32_t    color_argb;
    int32_t     sort_index;
} WkTabGroup;

typedef struct {
    const WkTabGroup* groups;
    size_t            count;
    void*             _opaque;
} WkTabGroupList;

int     wk_tab_groups_list(WkSuggestionsIndex* index,
                            WkTabGroupList* out_list);
int64_t wk_tab_groups_add(WkSuggestionsIndex* index,
                           const char* name,
                           uint32_t color_argb);
void    wk_tab_groups_remove(WkSuggestionsIndex* index,
                              int64_t group_id);
void    wk_tab_groups_release(WkTabGroupList* list);

// ---------- Open-tab persistence ----------

typedef struct {
    int64_t     window_id;
    int32_t     sort_index;
    const char* url;
    const char* title;
    int64_t     group_id;
    int32_t     is_pinned;
    int32_t     is_active;
} WkOpenTab;

typedef struct {
    const WkOpenTab* tabs;
    size_t           count;
    void*            _opaque;
} WkOpenTabList;

int  wk_open_tabs_list(WkSuggestionsIndex* index,
                        int64_t window_id,
                        WkOpenTabList* out_list);
// Replaces all rows for window_id atomically.
void wk_open_tabs_set(WkSuggestionsIndex* index,
                       int64_t window_id,
                       const WkOpenTab* tabs,
                       size_t count);
void wk_open_tabs_release(WkOpenTabList* list);

// ---------- Downloads ----------

typedef struct {
    int64_t     id;
    const char* filename;
    const char* source_url;
    const char* dest_path;
    int64_t     bytes_total;
    int64_t     bytes_received;
    int64_t     started_ms;
    int64_t     completed_ms; // 0 = in-flight
} WkDownload;

typedef struct {
    const WkDownload* downloads;
    size_t            count;
    void*             _opaque;
} WkDownloadList;

int     wk_downloads_list(WkSuggestionsIndex* index,
                           size_t limit,
                           WkDownloadList* out_list);
int64_t wk_downloads_start(WkSuggestionsIndex* index,
                            const char* filename,
                            const char* source_url,
                            const char* dest_path,
                            int64_t bytes_total);
void    wk_downloads_progress(WkSuggestionsIndex* index,
                               int64_t id,
                               int64_t bytes_received);
void    wk_downloads_complete(WkSuggestionsIndex* index, int64_t id);
void    wk_downloads_cancel  (WkSuggestionsIndex* index, int64_t id);
void    wk_downloads_release (WkDownloadList* list);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_SUGGESTIONS_BRIDGE_C_H_
