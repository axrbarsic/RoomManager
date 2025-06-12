package com.roommanager.android.utils

import android.content.Context
import android.content.SharedPreferences
import com.roommanager.android.ui.components.CellStyle

/**
 * Менеджер для сохранения и загрузки настроек приложения
 * Использует SharedPreferences для постоянного хранения
 */
class PreferencesManager private constructor(context: Context) {
    
    companion object {
        private const val PREFS_NAME = "room_manager_prefs"
        private const val KEY_HIDE_WHITE_ROOMS = "hide_white_rooms"
        private const val KEY_CELL_STYLE = "cell_style"
        private const val KEY_SHOW_MARKED_ONLY = "show_marked_only"
        private const val KEY_SELECTED_COLOR_FILTER = "selected_color_filter"
        
        @Volatile
        private var INSTANCE: PreferencesManager? = null
        
        fun getInstance(context: Context): PreferencesManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: PreferencesManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    private val sharedPreferences: SharedPreferences = 
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * Сохранить настройку скрытия белых комнат
     */
    fun setHideWhiteRooms(hide: Boolean) {
        sharedPreferences.edit()
            .putBoolean(KEY_HIDE_WHITE_ROOMS, hide)
            .apply()
    }
    
    /**
     * Получить настройку скрытия белых комнат
     */
    fun getHideWhiteRooms(): Boolean {
        return sharedPreferences.getBoolean(KEY_HIDE_WHITE_ROOMS, false)
    }
    
    /**
     * Сохранить стиль ячеек
     */
    fun setCellStyle(style: CellStyle) {
        sharedPreferences.edit()
            .putString(KEY_CELL_STYLE, style.name)
            .apply()
    }
    
    /**
     * Получить стиль ячеек
     */
    fun getCellStyle(): CellStyle {
        val styleName = sharedPreferences.getString(KEY_CELL_STYLE, CellStyle.FLAT.name)
        return try {
            CellStyle.valueOf(styleName ?: CellStyle.FLAT.name)
        } catch (e: IllegalArgumentException) {
            CellStyle.FLAT // Возвращаем по умолчанию если неизвестное значение
        }
    }
    
    /**
     * Сохранить настройку показа только помеченных комнат
     */
    fun setShowMarkedOnly(show: Boolean) {
        sharedPreferences.edit()
            .putBoolean(KEY_SHOW_MARKED_ONLY, show)
            .apply()
    }
    
    /**
     * Получить настройку показа только помеченных комнат
     */
    fun getShowMarkedOnly(): Boolean {
        return sharedPreferences.getBoolean(KEY_SHOW_MARKED_ONLY, false)
    }
    
    /**
     * Сохранить выбранный цветовой фильтр
     */
    fun setSelectedColorFilter(filter: String?) {
        sharedPreferences.edit()
            .putString(KEY_SELECTED_COLOR_FILTER, filter)
            .apply()
    }
    
    /**
     * Получить выбранный цветовой фильтр
     */
    fun getSelectedColorFilter(): String? {
        return sharedPreferences.getString(KEY_SELECTED_COLOR_FILTER, null)
    }
    
    /**
     * Очистить все настройки (для сброса к значениям по умолчанию)
     */
    fun clearAll() {
        sharedPreferences.edit().clear().apply()
    }
    
    /**
     * Проверить, были ли уже сохранены настройки
     */
    fun hasSettings(): Boolean {
        return sharedPreferences.contains(KEY_HIDE_WHITE_ROOMS) || 
               sharedPreferences.contains(KEY_CELL_STYLE)
    }
} 