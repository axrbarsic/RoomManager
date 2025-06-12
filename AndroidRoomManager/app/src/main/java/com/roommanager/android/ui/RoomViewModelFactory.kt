package com.roommanager.android.ui

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

/**
 * Фабрика для создания RoomViewModel с передачей контекста
 * Необходима для работы с настройками через PreferencesManager
 */
class RoomViewModelFactory(private val context: Context) : ViewModelProvider.Factory {
    
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(RoomViewModel::class.java)) {
            return RoomViewModel(context) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
} 