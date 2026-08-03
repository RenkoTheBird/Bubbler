package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiException

internal fun TokenStore.requireAccessToken(): String =
    loadAccessToken() ?: throw ApiException.Unauthorized
