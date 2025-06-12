package com.roommanager.android.utils

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * Утилитный класс для управления локализацией приложения
 * Поддерживает: русский (по умолчанию), английский, украинский, испанский, гаитянский креольский
 */
object LocaleHelper {
    
    /**
     * Доступные языки
     */
    enum class SupportedLanguage(val code: String, val displayName: String) {
        RUSSIAN("ru", "Русский"),
        ENGLISH("en", "English"),
        UKRAINIAN("uk", "Українська"),
        SPANISH("es", "Español"),
        HAITIAN_CREOLE("ht", "Kreyòl Ayisyen")
    }
    
    private const val PREF_LANGUAGE = "selected_language"
    
    /**
     * Устанавливает язык приложения
     */
    fun setLanguage(context: Context, languageCode: String): Context {
        val locale = Locale(languageCode)
        Locale.setDefault(locale)
        
        val config = Configuration()
        config.setLocale(locale)
        
        // Сохраняем выбранный язык
        context.getSharedPreferences("locale_prefs", Context.MODE_PRIVATE)
            .edit()
            .putString(PREF_LANGUAGE, languageCode)
            .apply()
        
        return context.createConfigurationContext(config)
    }
    
    /**
     * Получает сохраненный язык или автоматически определяет язык системы при первом запуске
     */
    fun getSavedLanguage(context: Context): String {
        val prefs = context.getSharedPreferences("locale_prefs", Context.MODE_PRIVATE)
        val savedLanguage = prefs.getString(PREF_LANGUAGE, null)
        
        // Если язык не был сохранен ранее (первый запуск)
        if (savedLanguage == null) {
            val systemLanguage = getSystemLanguage()
            val supportedLanguage = if (isLanguageSupported(systemLanguage)) {
                systemLanguage
            } else {
                "ru" // Русский как fallback
            }
            
            // Сохраняем определенный язык
            prefs.edit()
                .putString(PREF_LANGUAGE, supportedLanguage)
                .apply()
                
            return supportedLanguage
        }
        
        return savedLanguage
    }
    
    /**
     * Получает отображаемое имя языка по коду
     */
    fun getLanguageDisplayName(languageCode: String): String {
        return SupportedLanguage.values().find { it.code == languageCode }?.displayName 
            ?: SupportedLanguage.RUSSIAN.displayName
    }
    
    /**
     * Получает все поддерживаемые языки
     */
    fun getSupportedLanguages(): List<SupportedLanguage> {
        return SupportedLanguage.values().toList()
    }
    
    /**
     * Применяет локализацию к контексту
     */
    fun wrapContext(context: Context): Context {
        val savedLanguage = getSavedLanguage(context)
        return setLanguage(context, savedLanguage)
    }
    
    /**
     * Получает язык системы
     */
    private fun getSystemLanguage(): String {
        return Locale.getDefault().language
    }
    
    /**
     * Проверяет, поддерживается ли язык приложением
     */
    private fun isLanguageSupported(languageCode: String): Boolean {
        return SupportedLanguage.values().any { it.code == languageCode }
    }
    
    /**
     * Получает информацию об автоопределении языка (для отладки)
     */
    fun getLanguageDetectionInfo(context: Context): String {
        val systemLanguage = getSystemLanguage()
        val isSupported = isLanguageSupported(systemLanguage)
        val selectedLanguage = getSavedLanguage(context)
        
        return """
            Системный язык: $systemLanguage
            Поддерживается: $isSupported
            Выбранный язык: $selectedLanguage
            Доступные языки: ${SupportedLanguage.values().joinToString { it.code }}
        """.trimIndent()
    }
} 