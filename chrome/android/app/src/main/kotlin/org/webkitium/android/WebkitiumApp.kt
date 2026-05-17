package org.webkitium.android

import android.app.Application

/**
 * Application entry. Trivial for now; later instances of the FFI
 * suggestion provider, bookmarks store, etc. will live here so they
 * survive Activity rotation.
 */
class WebkitiumApp : Application()
